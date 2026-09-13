import { BullModule } from "@nestjs/bullmq";
import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ParseController } from "./parse.controller";
import { ParseService } from "./parse.service";
import { ParseEventsService } from "./parse-events.service";
import { ParseJobEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";
import { SkillModule } from "../skill/skill.module";
import { LabModule } from "../lab/lab.module";
import { StorageModule } from "../../storage/storage.module";
import { PARSE_QUEUE } from "./parse.constants";

@Module({
  imports: [
    BullModule.registerQueue({ name: PARSE_QUEUE }),
    TypeOrmModule.forFeature([ParseJobEntity]),
    PatientModule,
    SkillModule,
    LabModule,
    StorageModule,
  ],
  controllers: [ParseController],
  providers: [ParseService, ParseEventsService],
  exports: [ParseService],
})
export class ParseModule {}
