import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { InjectQueue } from "@nestjs/bullmq";
import { InjectRepository } from "@nestjs/typeorm";
import { Queue } from "bullmq";
import { Repository } from "typeorm";
import { ParseJobEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";
import { StorageService } from "../../storage/storage.service";
import { PARSE_QUEUE } from "./parse.module";

export interface EnqueueParseInput {
  patientId?: string;
  /** 直传后的 objectKey；与 text 二选一 */
  objectKey?: string;
  hospitalHint?: string;
  /** MVP：无对象存储时可直接塞报告文本 */
  text?: string;
  reportType?: string;
}

export interface ParseWorkerResult {
  engine: string;
  date?: string | null;
  items?: unknown[];
  skillVersion?: string | null;
  error?: string;
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
  ) {}

  async enqueue(input: EnqueueParseInput): Promise<ParseJobEntity> {
    if (!input.objectKey && !input.text) {
      throw new NotFoundException("objectKey or text required");
    }
    const patientId =
      input.patientId || (await this.patients.ensureDemoPatient()).id;
    const objectKey = input.objectKey ?? `inline://${patientId}`;
    const entity = await this.jobs.save(
      this.jobs.create({
        patientId,
        objectKey,
        hospitalHint: input.hospitalHint ?? null,
        status: "queued",
      }),
    );

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
          storage: {
            driver: this.storage.driver,
            localDir: process.env.STORAGE_LOCAL_DIR ?? "var/uploads",
            // worker 侧读 S3 时用环境变量；这里只传 driver 提示
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
      this.logger.log(`parse job ${entity.id} enqueued`);
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
    const job = await this.jobs.findOne({ where: { id } });
    if (!job) throw new NotFoundException(`parse job ${id} not found`);
    return job;
  }

  async list(patientId?: string): Promise<ParseJobEntity[]> {
    const pid = patientId || (await this.patients.ensureDemoPatient()).id;
    return this.jobs.find({
      where: { patientId: pid },
      order: { createdAt: "DESC" },
    });
  }

  async markCompleted(jobId: string, result: ParseWorkerResult) {
    const job = await this.jobs.findOne({ where: { id: jobId } });
    if (!job) return;
    await this.jobs.save({
      ...job,
      status: result.error ? "failed" : "done",
      items: result.items ?? [],
      skillVersionId: result.skillVersion ?? null,
      error: result.error ?? null,
    });
  }

  async markFailed(jobId: string, error: string) {
    const job = await this.jobs.findOne({ where: { id: jobId } });
    if (!job) return;
    await this.jobs.save({ ...job, status: "failed", error });
  }
}
