import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { InjectionEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";
import { addWeeks, getProtocol } from "./injection.protocols";

export type CreateInjectionDto = Omit<
  InjectionEntity,
  "id" | "patient" | "createdAt" | "updatedAt"
> &
  Partial<Pick<InjectionEntity, "patientId" | "actualDate" | "notes">>;

export interface GenerateScheduleInput {
  drugKey: string;
  startDate: string;
  /** 仅生成至该日（含） */
  untilDate?: string;
  notes?: string;
}

@Injectable()
export class InjectionService {
  constructor(
    @InjectRepository(InjectionEntity)
    private readonly injections: Repository<InjectionEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(userId: string, patientId?: string): Promise<InjectionEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.injections.find({
      where: { patientId: pid },
      order: { plannedDate: "ASC" },
    });
  }

  async upcoming(
    userId: string,
    patientId?: string,
    withinDays = 30,
  ): Promise<InjectionEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const until = new Date(Date.now() + withinDays * 86400000)
      .toISOString()
      .slice(0, 10);
    // 含逾期未打
    return this.injections
      .createQueryBuilder("i")
      .where("i.patientId = :pid", { pid })
      .andWhere("i.actualDate IS NULL")
      .andWhere("i.plannedDate <= :until", { until })
      .orderBy("i.plannedDate", "ASC")
      .getMany();
  }

  async create(userId: string, dto: CreateInjectionDto): Promise<InjectionEntity> {
    const patientId =
      dto.patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const { patient: _p, createdAt: _c, updatedAt: _u, ...rest } =
      dto as InjectionEntity;
    return this.injections.save(this.injections.create({ ...rest, patientId }));
  }

  /**
   * 按协议生成排期（诱导 + 维持）。
   * 已有同 patient+drug 的未完成计划时拒绝，避免重复。
   */
  async generateSchedule(userId: string, input: GenerateScheduleInput) {
    const protocol = getProtocol(input.drugKey);
    if (!protocol) {
      throw new NotFoundException(`unknown drugKey ${input.drugKey}`);
    }
    const patient = await this.patients.ensurePatientForUser(userId);

    const existing = await this.injections.count({
      where: { patientId: patient.id, drug: protocol.drugName, actualDate: null as never },
    });
    // 允许重新生成：先删该药未完成计划
    if (existing > 0) {
      await this.injections.delete({
        patientId: patient.id,
        drug: protocol.drugName,
        actualDate: null as never,
      });
    }

    const until = input.untilDate ?? addWeeks(input.startDate, 104);
    const rows: Partial<InjectionEntity>[] = [];

    for (const slot of protocol.induction) {
      const planned = addWeeks(input.startDate, slot.week);
      if (planned > until) continue;
      rows.push({
        patientId: patient.id,
        drug: protocol.drugName,
        plannedDate: planned,
        phase: slot.phase,
        dose: slot.dose,
        route: slot.route,
        weekNumber: slot.week,
        notes: slot.label ?? input.notes ?? null,
        actualDate: null,
      });
    }

    const count = protocol.maintenanceCount ?? 12;
    for (let i = 0; i < count; i++) {
      const week =
        protocol.maintenance.startWeek + i * protocol.maintenance.intervalWeeks;
      const planned = addWeeks(input.startDate, week);
      if (planned > until) break;
      rows.push({
        patientId: patient.id,
        drug: protocol.drugName,
        plannedDate: planned,
        phase: "maintenance",
        dose: protocol.maintenance.dose,
        route: protocol.maintenance.route,
        weekNumber: week,
        notes: input.notes ?? null,
        actualDate: null,
      });
    }

    const saved = await this.injections.save(
      rows.map((r) => this.injections.create(r as InjectionEntity)),
    );
    return {
      drug: protocol.drugName,
      startDate: input.startDate,
      count: saved.length,
      injections: saved,
    };
  }

  /**
   * 记录实际注射。若 delayDays>0 或实际日期晚于计划，自动顺延该药后续未完成计划。
   */
  async complete(
    userId: string,
    id: string,
    input: { actualDate?: string; rescheduleDelay?: boolean },
  ) {
    const job = await this.injections.findOne({ where: { id } });
    if (!job) throw new NotFoundException(`injection ${id} not found`);
    const patient = await this.patients.ensurePatientForUser(userId);
    if (job.patientId !== patient.id) {
      throw new NotFoundException(`injection ${id} not found`);
    }

    const actualDate =
      input.actualDate || new Date().toISOString().slice(0, 10);
    const delayDays = Math.max(
      0,
      Math.round(
        (new Date(`${actualDate}T00:00:00Z`).getTime() -
          new Date(`${job.plannedDate}T00:00:00Z`).getTime()) /
          86400000,
      ),
    );

    const updated = await this.injections.save({
      ...job,
      actualDate,
    });

    let shifted = 0;
    if (input.rescheduleDelay !== false && delayDays > 0) {
      const futures = await this.injections.find({
        where: {
          patientId: patient.id,
          drug: job.drug,
          actualDate: null as never,
        },
      });
      for (const f of futures) {
        if (f.plannedDate <= job.plannedDate) continue;
        const d = new Date(`${f.plannedDate}T00:00:00Z`);
        d.setUTCDate(d.getUTCDate() + delayDays);
        await this.injections.save({
          ...f,
          plannedDate: d.toISOString().slice(0, 10),
        });
        shifted += 1;
      }
    }

    return { injection: updated, delayDays, shifted };
  }
}
