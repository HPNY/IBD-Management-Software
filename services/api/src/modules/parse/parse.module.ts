import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ParseController } from "./parse.controller";
import { ParseService } from "./parse.service";
import { ParseJobEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

@Module({
  imports: [TypeOrmModule.forFeature([ParseJobEntity]), PatientModule],
  controllers: [ParseController],
  providers: [ParseService],
})
export class ParseModule {}
