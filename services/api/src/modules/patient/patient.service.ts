import { Injectable } from "@nestjs/common";
import type { PatientBasicInfo } from "../../domain/patient";

@Injectable()
export class PatientService {
  private readonly demo: PatientBasicInfo = {
    name: "demo",
    sex: "male",
    birthDate: "1990-01-01",
    diagnosisDate: "2022-12-01",
    ibdType: "crohns",
  };

  getBasic(patientId: string): PatientBasicInfo & { id: string } {
    return { id: patientId, ...this.demo };
  }
}
