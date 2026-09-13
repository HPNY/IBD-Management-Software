import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import {
  AdverseEventEntity,
  MedicationEntity,
} from "../../database/entities";
import { PatientService } from "../patient/patient.service";

export type CreateMedicationDto = {
  drugName: string;
  brandName?: string;
  category?: string;
  dosage: string;
  frequency: string;
  route: "oral" | "sc" | "iv";
  startDate: string;
  endDate?: string;
  status?: "active" | "paused" | "stopped";
  reason?: string;
  indication?: string;
};

export type AdjustMedicationDto = {
  dosage?: string;
  frequency?: string;
  reason: string;
  effectiveDate?: string;
};

export type SwitchMedicationDto = {
  fromId: string;
  stopReason: string;
  stopDate?: string;
  next: CreateMedicationDto;
};

export type CreateAdverseEventDto = {
  title: string;
  severity?: "mild" | "moderate" | "severe";
  occurredAt?: string;
  notes?: string;
};

@Injectable()
export class MedicationService {
  constructor(
    @InjectRepository(MedicationEntity)
    private readonly meds: Repository<MedicationEntity>,
    @InjectRepository(AdverseEventEntity)
    private readonly adverse: Repository<AdverseEventEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(userId: string, patientId?: string): Promise<MedicationEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.meds.find({
      where: { patientId: pid },
      order: { startDate: "DESC" },
    });
  }

  async listCurrent(
    userId: string,
    patientId?: string,
  ): Promise<MedicationEntity[]> {
    const all = await this.list(userId, patientId);
    return all.filter((m) => m.status === "active" || m.status === "paused");
  }

  async getOne(userId: string, id: string) {
    const med = await this.meds.findOne({ where: { id } });
    if (!med) throw new NotFoundException(`medication ${id} not found`);
    const patient = await this.patients.ensurePatientForUser(userId);
    if (med.patientId !== patient.id) {
      throw new NotFoundException(`medication ${id} not found`);
    }
    const events = await this.adverse.find({
      where: { medicationId: id },
      order: { occurredAt: "DESC" },
    });
    return { ...med, adverseEvents: events };
  }

  async create(userId: string, dto: CreateMedicationDto): Promise<MedicationEntity> {
    const patientId = (await this.patients.ensurePatientForUser(userId)).id;
    if (!dto.drugName || !dto.startDate) {
      throw new BadRequestException("drugName and startDate required");
    }
    return this.meds.save(
      this.meds.create({
        patientId,
        drugName: dto.drugName,
        brandName: dto.brandName ?? null,
        category: dto.category ?? null,
        dosage: dto.dosage,
        frequency: dto.frequency,
        route: dto.route,
        startDate: dto.startDate,
        endDate: dto.endDate ?? null,
        status: dto.status ?? "active",
        reason: dto.reason ?? null,
      }),
    );
  }

  async update(
    userId: string,
    id: string,
    dto: Partial<CreateMedicationDto>,
  ): Promise<MedicationEntity> {
    const med = await this.requireOwned(userId, id);
    return this.meds.save({ ...med, ...dto, id: med.id });
  }

  /** 调整剂量/频次：结束当前方案，开一条新记录（切换链可追溯）。 */
  async adjust(userId: string, id: string, dto: AdjustMedicationDto) {
    const med = await this.requireOwned(userId, id);
    if (!dto.reason) throw new BadRequestException("reason required");
    const effective = dto.effectiveDate || new Date().toISOString().slice(0, 10);

    const stopped = await this.meds.save({
      ...med,
      status: "stopped",
      endDate: effective,
      reason: `${med.reason ? med.reason + "；" : ""}调整：${dto.reason}`,
    });

    const next = await this.meds.save(
      this.meds.create({
        patientId: med.patientId,
        drugName: med.drugName,
        brandName: med.brandName,
        category: med.category,
        dosage: dto.dosage ?? med.dosage,
        frequency: dto.frequency ?? med.frequency,
        route: med.route,
        startDate: effective,
        endDate: null,
        status: "active",
        reason: `剂量调整：${dto.reason}`,
      }),
    );
    return { previous: stopped, current: next };
  }

  async setStatus(
    userId: string,
    id: string,
    status: "active" | "paused" | "stopped",
    reason?: string,
    endDate?: string,
  ) {
    const med = await this.requireOwned(userId, id);
    return this.meds.save({
      ...med,
      status,
      reason: reason ? `${med.reason ? med.reason + "；" : ""}${reason}` : med.reason,
      endDate:
        status === "stopped" ? endDate || new Date().toISOString().slice(0, 10) : med.endDate,
    });
  }

  /** 换药：停用旧药 + 开新药，同一事务语义。 */
  async switch(userId: string, dto: SwitchMedicationDto) {
    if (!dto.stopReason) throw new BadRequestException("stopReason required");
    const from = await this.requireOwned(userId, dto.fromId);
    const stopDate = dto.stopDate || new Date().toISOString().slice(0, 10);
    const stopped = await this.meds.save({
      ...from,
      status: "stopped",
      endDate: stopDate,
      reason: `${from.reason ? from.reason + "；" : ""}换药：${dto.stopReason}`,
    });
    const next = await this.create(userId, {
      ...dto.next,
      startDate: dto.next.startDate || stopDate,
      reason: dto.next.reason || `接替 ${from.drugName}`,
    });
    return { previous: stopped, current: next };
  }

  /** 用药切换链时间线（按开始日排序 + 副作用事件）。 */
  async timeline(userId: string, patientId?: string) {
    const meds = await this.list(userId, patientId);
    const events = await this.adverse
      .createQueryBuilder("ae")
      .innerJoin(MedicationEntity, "m", "m.id = ae.medicationId")
      .select([
        "ae.id AS id",
        "ae.medicationId AS \"medicationId\"",
        "ae.title AS title",
        "ae.severity AS severity",
        "ae.\"occurredAt\" AS \"occurredAt\"",
        "m.drugName AS \"drugName\"",
      ])
      .orderBy("ae.\"occurredAt\"", "ASC")
      .getRawMany();

    return {
      medications: meds.map((m) => ({
        id: m.id,
        drugName: m.drugName,
        brandName: m.brandName,
        category: m.category,
        dosage: m.dosage,
        frequency: m.frequency,
        route: m.route,
        startDate: m.startDate,
        endDate: m.endDate,
        status: m.status,
        reason: m.reason,
      })),
      adverseEvents: events,
      /** 一行摘要：修美乐→安健宁→乌帕替尼… */
      chainText: meds
        .slice()
        .sort((a, b) => a.startDate.localeCompare(b.startDate))
        .map((m) => m.drugName)
        .join("→"),
    };
  }

  async addAdverseEvent(userId: string, medId: string, dto: CreateAdverseEventDto) {
    const med = await this.requireOwned(userId, medId);
    if (!dto.title) throw new BadRequestException("title required");
    return this.adverse.save(
      this.adverse.create({
        medicationId: med.id,
        title: dto.title,
        severity: dto.severity ?? "mild",
        occurredAt: dto.occurredAt || new Date().toISOString().slice(0, 10),
        notes: dto.notes ?? null,
      }),
    );
  }

  async listAdverseEvents(userId: string, medId: string) {
    const med = await this.requireOwned(userId, medId);
    return this.adverse.find({
      where: { medicationId: med.id },
      order: { occurredAt: "DESC" },
    });
  }

  private async requireOwned(userId: string, id: string): Promise<MedicationEntity> {
    const med = await this.meds.findOne({ where: { id } });
    if (!med) throw new NotFoundException(`medication ${id} not found`);
    const patient = await this.patients.ensurePatientForUser(userId);
    if (med.patientId !== patient.id) {
      throw new NotFoundException(`medication ${id} not found`);
    }
    return med;
  }
}
