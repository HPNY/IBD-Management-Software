import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { PatientEntity } from "../../database/entities";

@Injectable()
export class PatientService {
  constructor(
    @InjectRepository(PatientEntity)
    private readonly patients: Repository<PatientEntity>,
  ) {}

  async getBasic(patientId: string): Promise<PatientEntity> {
    const found = await this.patients.findOne({ where: { id: patientId } });
    if (found) return found;
    throw new NotFoundException(`patient ${patientId} not found`);
  }

  /** 当前用户无档案时创建默认档案（MVP：一用户一患者）。 */
  async ensurePatientForUser(userId: string): Promise<PatientEntity> {
    const existing = await this.patients.findOne({ where: { userId } });
    if (existing) return existing;
    return this.patients.save(
      this.patients.create({
        userId,
        name: "me",
        sex: "male",
        birthDate: "1990-01-01",
        diagnosisDate: "2022-12-01",
        ibdType: "crohns",
      }),
    );
  }
}
