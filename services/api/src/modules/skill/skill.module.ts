import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import {
  ParseSkillEntity,
  ParseSkillVersionEntity,
} from "../../database/entities";
import { SkillController } from "./skill.controller";
import { SkillService } from "./skill.service";

@Module({
  imports: [
    TypeOrmModule.forFeature([ParseSkillEntity, ParseSkillVersionEntity]),
  ],
  controllers: [SkillController],
  providers: [SkillService],
  exports: [SkillService],
})
export class SkillModule {}
