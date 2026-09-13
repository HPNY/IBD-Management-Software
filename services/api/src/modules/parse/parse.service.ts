import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { InjectQueue } from "@nestjs/bullmq";
import { InjectRepository } from "@nestjs/typeorm";
import { Queue } from "bullmq";
import { Repository } from "typeorm";
import { ParseJobEntity } from "../../database/entities";
import { LabService } from "../lab/lab.service";
import { PatientService } from "../patient/patient.service";
import { SkillService } from "../skill/skill.service";
import { StorageService } from "../../storage/storage.service";
import { PARSE_QUEUE } from "./parse.constants";

export interface EnqueueParseInput {
  patientId?: string;
  objectKey?: string;
  hospitalHint?: string;
  text?: string;
  reportType?: string;
}

export interface ConfirmParseInput {
  items: Array<{
    nameNorm: string;
    nameRaw?: string;
    value: number;
    unit?: string;
    refMin?: number;
    refMax?: number;
    flag?: "high" | "low" | null;
  }>;
  date?: string;
  deviceId?: string;
  /** 默认 true：自动生成/升版 Skill */
  generateSkill?: boolean;
}

export interface ParseWorkerResult {
  engine: string;
  date?: string | null;
  items?: unknown[];
  skillVersion?: string | null;
  error?: string;
  engineDetail?: string | null;
}

@Injectable()
export class ParseService {
  private readonly logger = new Logger(ParseService.name);

  constructor(
    @InjectQueue(PARSE_QUEUE)
    private readonly queue: Queue,
    @InjectRepository(ParseJobEntity)
    private readonly jobs: Repository<ParseJobEntity>,
    private readonly patients: PatientService,
    private readonly storage: StorageService,
    private readonly skills: SkillService,
    private readonly labs: LabService,
  ) {}

  async enqueue(userId: string, input: EnqueueParseInput): Promise<ParseJobEntity> {
    if (!input.objectKey && !input.text) {
      throw new NotFoundException("objectKey or text required");
    }
    const patientId =
      input.patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const objectKey = input.objectKey ?? `inline://${patientId}`;
    const entity = await this.jobs.save(
      this.jobs.create({
        patientId,
        objectKey,
        hospitalHint: input.hospitalHint ?? null,
        reportType: input.reportType ?? null,
        status: "queued",
      }),
    );

    // 库内 Skill 优先，随任务下发给 worker
    let skill: unknown = null;
    if (input.hospitalHint && input.reportType) {
      skill = await this.skills.getActiveSkillContent(
        input.hospitalHint,
        input.reportType,
      );
    }

    try {
      await this.queue.add(
        "parsePdf",
        {
          jobId: entity.id,
          patientId,
          objectKey: input.objectKey ?? null,
          hospitalHint: input.hospitalHint ?? null,
          text: input.text ?? null,
          reportType: input.reportType ?? null,
          skill,
          storage: {
            driver: this.storage.driver,
            localDir: process.env.STORAGE_LOCAL_DIR ?? "var/uploads",
            bucket: process.env.S3_BUCKET ?? null,
            endpoint: process.env.S3_ENDPOINT ?? null,
          },
        },
        {
          jobId: entity.id,
          attempts: 2,
          removeOnComplete: 100,
          removeOnFail: 200,
        },
      );
      this.logger.log(
        `parse job ${entity.id} enqueued skill=${skill ? "db" : "none"}`,
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error(`enqueue failed for ${entity.id}: ${message}`);
      return this.jobs.save({
        ...entity,
        status: "failed",
        error: `queue unavailable: ${message}`,
      });
    }

    return this.jobs.save({ ...entity, status: "running" });
  }

  async get(id: string): Promise<ParseJobEntity> {
    let job = await this.jobs.findOne({ where: { id } });
    if (!job) throw new NotFoundException(`parse job ${id} not found`);
    // QueueEvents 不可靠时的兜底：从 BullMQ 拉终态
    if (job.status === "queued" || job.status === "running") {
      try {
        const qJob = await this.queue.getJob(id);
        if (qJob) {
          const state = await qJob.getState();
          if (state === "completed") {
            const ret = qJob.returnvalue as ParseWorkerResult | string;
            const result =
              typeof ret === "string" ? (JSON.parse(ret) as ParseWorkerResult) : ret;
            await this.markCompleted(id, result ?? {});
            job = (await this.jobs.findOne({ where: { id } })) ?? job;
          } else if (state === "failed") {
            await this.markFailed(id, qJob.failedReason || "worker failed");
            job = (await this.jobs.findOne({ where: { id } })) ?? job;
          }
        }
      } catch (e) {
        this.logger.debug(`queue sync skip ${id}: ${String(e)}`);
      }
    }
    return job;
  }

  async list(userId: string, patientId?: string): Promise<ParseJobEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.jobs.find({
      where: { patientId: pid },
      order: { createdAt: "DESC" },
    });
  }

  /**
   * 用户确认解析结果 → 写 LabResult，并自动生成/升版 ParseSkill。
   */
  async confirm(userId: string, jobId: string, input: ConfirmParseInput) {
    const job = await this.get(jobId);
    if (!input.items?.length) {
      throw new NotFoundException("items required");
    }
    const date =
      input.date ||
      job.reportDate ||
      new Date().toISOString().slice(0, 10);

    const lab = await this.labs.create(userId, {
      patientId: job.patientId,
      date,
      hospital: job.hospitalHint ?? undefined,
      items: input.items,
      source: "skill",
      deviceId: input.deviceId || "confirm",
    });

    let skillResult: Awaited<ReturnType<SkillService["upsertFromConfirmed"]>> | null =
      null;
    if (input.generateSkill !== false && job.hospitalHint && job.reportType) {
      try {
        skillResult = await this.skills.upsertFromConfirmed({
          hospital: job.hospitalHint,
          reportType: job.reportType,
          items: input.items,
          reportDate: date,
          userId,
        });
      } catch (e) {
        this.logger.warn(`skill upsert failed: ${String(e)}`);
      }
    }

    const updated = await this.jobs.save({
      ...job,
      confirmedItems: input.items,
      confirmedAt: new Date(),
      labResultId: lab.id,
      reportDate: date,
      skillVersionId: skillResult?.versionId ?? job.skillVersionId,
    });

    return {
      job: updated,
      labResultId: lab.id,
      skill: skillResult,
    };
  }

  async markCompleted(jobId: string, result: ParseWorkerResult) {
    const job = await this.jobs.findOne({ where: { id: jobId } });
    if (!job) return;
    const rawDate = result.date;
    const reportDate =
      rawDate && /^\d{4}-\d{2}-\d{2}$/.test(rawDate) ? rawDate : job.reportDate;
    await this.jobs.save({
      ...job,
      status: result.error ? "failed" : "done",
      items: result.items ?? [],
      skillVersionId: result.skillVersion ?? null,
      error: result.error ?? null,
      reportDate,
    });
  }

  async markFailed(jobId: string, error: string) {
    const job = await this.jobs.findOne({ where: { id: jobId } });
    if (!job) return;
    await this.jobs.save({ ...job, status: "failed", error });
  }
}
