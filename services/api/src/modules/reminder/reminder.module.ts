import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ReminderController } from "./reminder.controller";
import { ReminderService } from "./reminder.service";
import { InjectionEntity, ReminderRuleEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([ReminderRuleEntity, InjectionEntity]),
    PatientModule,
  ],
  controllers: [ReminderController],
  providers: [ReminderService],
  exports: [ReminderService],
})
export class ReminderModule {}
