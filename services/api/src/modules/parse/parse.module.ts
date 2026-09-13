import { BullModule } from "@nestjs/bullmq";
import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ParseController } from "./parse.controller";
import { ParseService } from "./parse.service";
import { ParseEventsService } from "./parse-events.service";
import { ParseJobEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

export const PARSE_QUEUE = "parse";

@Module({
  imports: [
    BullModule.registerQueue({ name: PARSE_QUEUE }),
    TypeOrmModule.forFeature([ParseJobEntity]),
    PatientModule,
  ],
  controllers: [ParseController],
  providers: [ParseService, ParseEventsService],
  exports: [ParseService],
})
export class ParseModule {}
