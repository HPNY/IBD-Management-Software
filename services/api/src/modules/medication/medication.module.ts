import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { MedicationController } from "./medication.controller";
import { MedicationService } from "./medication.service";
import { AdverseEventEntity, MedicationEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([MedicationEntity, AdverseEventEntity]),
    PatientModule,
  ],
  controllers: [MedicationController],
  providers: [MedicationService],
  exports: [MedicationService],
})
export class MedicationModule {}
