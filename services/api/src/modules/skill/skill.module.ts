import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import {
  ParseSkillEntity,
  ParseSkillVersionEntity,
  SkillRatingEntity,
} from "../../database/entities";
import { SkillController } from "./skill.controller";
import { SkillService } from "./skill.service";
import { SkillCommunityController } from "./skill-community.controller";
import { SkillCommunityService } from "./skill-community.service";

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ParseSkillEntity,
      ParseSkillVersionEntity,
      SkillRatingEntity,
    ]),
  ],
  controllers: [SkillController, SkillCommunityController],
  providers: [SkillService, SkillCommunityService],
  exports: [SkillService, SkillCommunityService],
})
export class SkillModule {}
