import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { SymptomController } from "./symptom.controller";
import { SymptomService } from "./symptom.service";
import { SymptomDiaryEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

@Module({
  imports: [TypeOrmModule.forFeature([SymptomDiaryEntity]), PatientModule],
  controllers: [SymptomController],
  providers: [SymptomService],
})
export class SymptomModule {}
