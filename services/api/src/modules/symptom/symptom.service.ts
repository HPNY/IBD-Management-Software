import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { SymptomDiaryEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";

export type UpsertSymptomDto = Partial<
  Omit<SymptomDiaryEntity, "patient" | "createdAt" | "updatedAt">
> & {
  date: string;
  patientId?: string;
};

@Injectable()
export class SymptomService {
  constructor(
    @InjectRepository(SymptomDiaryEntity)
    private readonly diaries: Repository<SymptomDiaryEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(userId: string, patientId?: string): Promise<SymptomDiaryEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.diaries.find({
      where: { patientId: pid },
      order: { date: "DESC" },
    });
  }

  async upsert(userId: string, dto: UpsertSymptomDto): Promise<SymptomDiaryEntity> {
    const patientId =
      dto.patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const existing = await this.diaries.findOne({
      where: { patientId, date: dto.date },
    });
    const payload = {
      painLevel: dto.painLevel ?? null,
      diarrheaCount: dto.diarrheaCount ?? null,
      stoolType: dto.stoolType ?? null,
      bloodyStool: dto.bloodyStool ?? null,
      bloating: dto.bloating ?? null,
      fatigue: dto.fatigue ?? null,
      nausea: dto.nausea ?? null,
      overallFeeling: dto.overallFeeling ?? null,
    };
    if (existing) {
      return this.diaries.save({ ...existing, ...payload });
    }
    return this.diaries.save(
      this.diaries.create({ patientId, date: dto.date, ...payload }),
    );
  }
}
