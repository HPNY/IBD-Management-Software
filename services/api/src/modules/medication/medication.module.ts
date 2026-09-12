import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { MedicationController } from "./medication.controller";
import { MedicationService } from "./medication.service";
import { MedicationEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

@Module({
  imports: [TypeOrmModule.forFeature([MedicationEntity]), PatientModule],
  controllers: [MedicationController],
  providers: [MedicationService],
})
export class MedicationModule {}
