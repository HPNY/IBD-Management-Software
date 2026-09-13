import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { CreateLabDto, LabService } from "./lab.service";

@ApiTags("lab")
@ApiBearerAuth()
@Controller("labs")
export class LabController {
  constructor(private readonly labs: LabService) {}

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.labs.list(user.userId, patientId);
  }

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateLabDto) {
    return this.labs.create(user.userId, dto);
  }
}
