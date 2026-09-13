import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { LabItemEntity, LabResultEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";

export interface LabItemDto {
  nameNorm: string;
  nameRaw?: string;
  value: number;
  unit?: string;
  refMin?: number;
  refMax?: number;
  flag?: "high" | "low" | null;
}

export interface CreateLabDto {
  patientId?: string;
  date: string;
  hospital?: string;
  items: LabItemDto[];
  source?: "skill" | "ai" | "manual";
  deviceId: string;
  hlcWallMs?: number;
  hlcCounter?: number;
}

@Injectable()
export class LabService {
  constructor(
    @InjectRepository(LabResultEntity)
    private readonly labs: Repository<LabResultEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(userId: string, patientId?: string): Promise<LabResultEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.labs.find({
      where: { patientId: pid },
      order: { date: "DESC", createdAt: "DESC" },
    });
  }

  async create(userId: string, dto: CreateLabDto): Promise<LabResultEntity> {
    const patientId =
      dto.patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const entity = this.labs.create({
      patientId,
      date: dto.date,
      hospital: dto.hospital ?? null,
      source: dto.source ?? "manual",
      deviceId: dto.deviceId,
      hlcWallMs: String(dto.hlcWallMs ?? Date.now()),
      hlcCounter: dto.hlcCounter ?? 0,
      items: (dto.items ?? []).map((i) => ({
        nameNorm: i.nameNorm,
        nameRaw: i.nameRaw ?? i.nameNorm,
        value: i.value,
        unit: i.unit ?? null,
        refMin: i.refMin ?? null,
        refMax: i.refMax ?? null,
        flag: i.flag ?? null,
      })) as LabItemEntity[],
    });
    return this.labs.save(entity);
  }
}
