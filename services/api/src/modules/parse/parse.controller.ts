import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { EnqueueParseInput, ParseService } from "./parse.service";

@ApiTags("parse")
@ApiBearerAuth()
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

  @Get(":id")
  get(@Param("id") id: string) {
    return this.parse.get(id);
  }
}
