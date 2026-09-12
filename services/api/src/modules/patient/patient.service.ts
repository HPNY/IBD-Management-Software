import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { PatientEntity } from "../../database/entities";
import { AuthService } from "../auth/auth.service";

@Injectable()
export class PatientService {
  constructor(
    @InjectRepository(PatientEntity)
    private readonly patients: Repository<PatientEntity>,
    private readonly auth: AuthService,
  ) {}

  async getBasic(patientId: string): Promise<PatientEntity> {
    const found = await this.patients.findOne({ where: { id: patientId } });
    if (found) return found;
    throw new NotFoundException(`patient ${patientId} not found`);
  }

  /** MVP：不存在则建 demo 患者，便于联调。 */
  async ensureDemoPatient(): Promise<PatientEntity> {
    const user = await this.auth.ensureDemoUser();
    const existing = await this.patients.findOne({ where: { userId: user.id } });
    if (existing) return existing;
    return this.patients.save(
      this.patients.create({
        userId: user.id,
        name: "demo",
        sex: "male",
        birthDate: "1990-01-01",
        diagnosisDate: "2022-12-01",
        ibdType: "crohns",
      }),
    );
  }
}
