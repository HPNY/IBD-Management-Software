import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { ReminderRuleEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";

export type CreateReminderDto = Omit<
  ReminderRuleEntity,
  "id" | "patient" | "createdAt" | "updatedAt"
> &
  Partial<Pick<ReminderRuleEntity, "patientId" | "enabled">>;

@Injectable()
export class ReminderService {
  constructor(
    @InjectRepository(ReminderRuleEntity)
    private readonly rules: Repository<ReminderRuleEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(userId: string, patientId?: string): Promise<ReminderRuleEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.rules.find({ where: { patientId: pid } });
  }

  async create(userId: string, dto: CreateReminderDto): Promise<ReminderRuleEntity> {
    const patientId =
      dto.patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const { patient: _p, createdAt: _c, updatedAt: _u, ...rest } =
      dto as ReminderRuleEntity;
    return this.rules.save(
      this.rules.create({ ...rest, patientId, enabled: dto.enabled ?? true }),
    );
  }
}
