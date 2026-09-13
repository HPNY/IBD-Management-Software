import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { HealthController } from "./health.controller";
import { entities } from "../database/entities";

@Module({
  imports: [TypeOrmModule.forFeature(entities)],
  controllers: [HealthController],
})
export class HealthModule {}
