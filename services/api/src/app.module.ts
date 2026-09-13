import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { BullModule } from "@nestjs/bullmq";
import { TypeOrmModule } from "@nestjs/typeorm";
import { HealthModule } from "./common/health.module";
import { AuthModule } from "./auth/auth.module";
import { PatientModule } from "./modules/patient/patient.module";
import { LabModule } from "./modules/lab/lab.module";
import { MedicationModule } from "./modules/medication/medication.module";
import { InjectionModule } from "./modules/injection/injection.module";
import { SymptomModule } from "./modules/symptom/symptom.module";
import { ParseModule } from "./modules/parse/parse.module";
import { ReminderModule } from "./modules/reminder/reminder.module";
import { SyncModule } from "./modules/sync/sync.module";
import { StorageModule } from "./storage/storage.module";
import { dataSourceOptions } from "./database/data-source";

const redisUrl = process.env.REDIS_URL ?? "redis://localhost:6379";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRoot(dataSourceOptions),
    BullModule.forRoot({
      connection: { url: redisUrl },
    }),
    AuthModule,
    HealthModule,
    PatientModule,
    LabModule,
    MedicationModule,
    InjectionModule,
    SymptomModule,
    ParseModule,
    ReminderModule,
    SyncModule,
    StorageModule,
  ],
})
export class AppModule {}
