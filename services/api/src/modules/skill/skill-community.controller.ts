import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";
import {
  PublishDto,
  RateDto,
  SkillCommunityService,
} from "./skill-community.service";

@ApiTags("skill-community")
@ApiBearerAuth()
@UseGuards(RequireScope("full", "community"))
@Controller("skill-community")
export class SkillCommunityController {
  constructor(private readonly community: SkillCommunityService) {}

  private hashOf(req: { user?: JwtUser }): string {
    // 匿名：仅 appUserId，不暴露手机号
    return req.user?.appUserId ?? req.user?.userId ?? "anon";
  }

  @Post("skills")
  publish(@Body() body: PublishDto, @Req() req: { user?: JwtUser }) {
    return this.community.publish({
      skill: body.skill,
      raterHash: this.hashOf(req),
      parentVersion: body.parentVersion,
    });
  }

  @Get("skills")
  search(
    @Query("hospital") hospital?: string,
    @Query("reportType") reportType?: string,
    @Query("q") q?: string,
  ) {
    return this.community.search({ hospital, reportType, q });
  }

  @Get("skills/:id")
  detail(@Param("id") id: string) {
    return this.community.getDetail(id);
  }

  @Get("skills/:id/content")
  content(@Param("id") id: string) {
    return this.community.getCurrentContent(id);
  }

  @Post("skills/:id/ratings")
  rate(
    @Param("id") id: string,
    @Body() body: { score: number; comment?: string; versionId?: string },
    @Req() req: { user?: JwtUser },
  ) {
    const dto: RateDto = {
      skillId: id,
      score: body.score,
      comment: body.comment,
      versionId: body.versionId,
      raterHash: this.hashOf(req),
    };
    return this.community.rate(dto);
  }

  @Post("skills/:id/collaborate")
  collaborate(
    @Param("id") id: string,
    @Body() body: { skill: unknown },
    @Req() req: { user?: JwtUser },
  ) {
    return this.community.collaborate({
      skillId: id,
      skill: body.skill,
      raterHash: this.hashOf(req),
    });
  }
}
