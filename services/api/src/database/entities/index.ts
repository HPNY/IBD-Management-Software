export { DeviceEntity } from "./device.entity";
export { InjectionEntity } from "./injection.entity";
export { LabItemEntity } from "./lab-item.entity";
export { LabResultEntity } from "./lab-result.entity";
export { MedicationEntity } from "./medication.entity";
export { ParseJobEntity } from "./parse-job.entity";
export { PatientEntity } from "./patient.entity";
export { RefreshTokenEntity } from "./refresh-token.entity";
export { ReminderRuleEntity } from "./reminder-rule.entity";
export { SymptomDiaryEntity } from "./symptom-diary.entity";
export { UserEntity } from "./user.entity";

import { DeviceEntity } from "./device.entity";
import { InjectionEntity } from "./injection.entity";
import { LabItemEntity } from "./lab-item.entity";
import { LabResultEntity } from "./lab-result.entity";
import { MedicationEntity } from "./medication.entity";
import { ParseJobEntity } from "./parse-job.entity";
import { PatientEntity } from "./patient.entity";
import { RefreshTokenEntity } from "./refresh-token.entity";
import { ReminderRuleEntity } from "./reminder-rule.entity";
import { SymptomDiaryEntity } from "./symptom-diary.entity";
import { UserEntity } from "./user.entity";

export const entities = [
  UserEntity,
  DeviceEntity,
  PatientEntity,
  LabResultEntity,
  LabItemEntity,
  MedicationEntity,
  InjectionEntity,
  SymptomDiaryEntity,
  ParseJobEntity,
  ReminderRuleEntity,
  RefreshTokenEntity,
];
