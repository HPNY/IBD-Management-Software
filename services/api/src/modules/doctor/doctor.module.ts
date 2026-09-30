import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ConfigModule, ConfigService } from "@nestjs/config";
import {
  DoctorEntity,
  DoctorGrantEntity,
  PatientEntity,
} from "../../database/entities";
import {
  DoctorAuthService,
  DoctorGrantService,
} from "./doctor.service";
import {
  DoctorController,
  DoctorGrantController,
} from "./doctor.controller";

@Module({
  imports: [
    TypeOrmModule.forFeature([DoctorEntity, DoctorGrantEntity, PatientEntity]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        secret: cfg.get("JWT_SECRET") || "dev-secret",
      }),
    }),
  ],
  controllers: [DoctorController, DoctorGrantController],
  providers: [DoctorAuthService, DoctorGrantService],
  exports: [DoctorAuthService, DoctorGrantService],
})
export class DoctorModule {}
