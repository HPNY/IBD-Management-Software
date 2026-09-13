import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { MedicationEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";

export type CreateMedicationDto = Omit<
  MedicationEntity,
  "id" | "patient" | "createdAt" | "updatedAt"
> &
  Partial<Pick<MedicationEntity, "patientId" | "brandName" | "category" | "endDate" | "reason">>;

@Injectable()
export class MedicationService {
  constructor(
    @InjectRepository(MedicationEntity)
    private readonly meds: Repository<MedicationEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(userId: string, patientId?: string): Promise<MedicationEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.meds.find({
      where: { patientId: pid },
      order: { startDate: "DESC" },
    });
  }

  async create(userId: string, dto: CreateMedicationDto): Promise<MedicationEntity> {
    const patientId =
      dto.patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const { patient: _p, createdAt: _c, updatedAt: _u, ...rest } =
      dto as MedicationEntity;
    return this.meds.save(this.meds.create({ ...rest, patientId }));
  }
}
