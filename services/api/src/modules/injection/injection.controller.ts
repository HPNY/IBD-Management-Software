import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { CreateInjectionDto, InjectionService } from "./injection.service";

@ApiTags("injection")
@ApiBearerAuth()
@Controller("injections")
export class InjectionController {
  constructor(private readonly injections: InjectionService) {}

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.injections.list(user.userId, patientId);
  }

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateInjectionDto) {
    return this.injections.create(user.userId, dto);
  }
}
