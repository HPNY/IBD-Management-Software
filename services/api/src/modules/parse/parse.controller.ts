import { Body, Controller, Get, Param, Post, Query, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";
import {
  ConfirmParseInput,
  EnqueueParseInput,
  ParseService,
} from "./parse.service";

@ApiTags("parse")
@ApiBearerAuth()
@UseGuards(RequireScope("full", "parse_session"))
@Controller("parse/jobs")
export class ParseController {
  constructor(private readonly parse: ParseService) {}

  @Post()
  enqueue(@CurrentUser() user: JwtUser, @Body() body: EnqueueParseInput) {
    return this.parse.enqueue(user.userId, body);
  }

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.parse.list(user.userId, patientId);
  }

  /** 确认解析结果 → 写 labs + 自动生成/升版 Skill */
  @Post(":id/confirm")
  confirm(
    @CurrentUser() user: JwtUser,
    @Param("id") id: string,
    @Body() body: ConfirmParseInput,
  ) {
    return this.parse.confirm(user.userId, id, body);
  }

  /** 用完即删：删除该 job 的云端 PDF 原件 */
  @Post(":id/delete-source")
  deleteSource(@CurrentUser() user: JwtUser, @Param("id") id: string) {
    return this.parse.deleteSource(user.userId, id);
  }

  @Get(":id")
  get(@CurrentUser() user: JwtUser, @Param("id") id: string) {
    return this.parse.getForUser(user.userId, id);
  }
}
