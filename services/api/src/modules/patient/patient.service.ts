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

  /** 归属校验：patientId 必须属于当前 user，否则 404（防 IDOR）。 */
  async resolveOwnedPatientId(
    userId: string,
    patientId?: string,
  ): Promise<string> {
    const own = await this.ensurePatientForUser(userId);
    if (!patientId || patientId === own.id) return own.id;
    const row = await this.patients.findOne({ where: { id: patientId } });
    if (!row || row.userId !== userId) {
      throw new NotFoundException(`patient ${patientId} not found`);
    }
    return row.id;
  }
}
