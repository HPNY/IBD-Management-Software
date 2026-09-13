import { Module } from "@nestjs/common";
import { SyncController } from "./sync.controller";
import { SyncService } from "./sync.service";
import { PatientModule } from "../patient/patient.module";
import { LabModule } from "../lab/lab.module";

@Module({
  imports: [PatientModule, LabModule],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule {}
