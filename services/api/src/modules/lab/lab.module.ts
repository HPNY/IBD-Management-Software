import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { LabController } from "./lab.controller";
import { LabService } from "./lab.service";
import { LabItemEntity, LabResultEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([LabResultEntity, LabItemEntity]),
    PatientModule,
  ],
  controllers: [LabController],
  providers: [LabService],
})
export class LabModule {}
