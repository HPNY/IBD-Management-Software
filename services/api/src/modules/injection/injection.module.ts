import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { InjectionController } from "./injection.controller";
import { InjectionService } from "./injection.service";
import { InjectionEntity } from "../../database/entities";
import { PatientModule } from "../patient/patient.module";

@Module({
  imports: [TypeOrmModule.forFeature([InjectionEntity]), PatientModule],
  controllers: [InjectionController],
  providers: [InjectionService],
})
export class InjectionModule {}
