import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { HealthModule } from "./common/health.module";
import { AuthModule } from "./modules/auth/auth.module";
import { PatientModule } from "./modules/patient/patient.module";
import { LabModule } from "./modules/lab/lab.module";
import { MedicationModule } from "./modules/medication/medication.module";
import { InjectionModule } from "./modules/injection/injection.module";
import { SymptomModule } from "./modules/symptom/symptom.module";
import { ParseModule } from "./modules/parse/parse.module";
import { ReminderModule } from "./modules/reminder/reminder.module";
import { SyncModule } from "./modules/sync/sync.module";
import { dataSourceOptions } from "./database/data-source";

@Module({
  imports: [
    TypeOrmModule.forRoot(dataSourceOptions),
    HealthModule,
    AuthModule,
    PatientModule,
    LabModule,
    MedicationModule,
    InjectionModule,
    SymptomModule,
    ParseModule,
    ReminderModule,
    SyncModule,
  ],
})
export class AppModule {}
