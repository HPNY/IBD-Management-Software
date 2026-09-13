import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { listProtocols } from "./injection.protocols";
import {
  CreateInjectionDto,
  GenerateScheduleInput,
  InjectionService,
} from "./injection.service";

@ApiTags("injection")
@ApiBearerAuth()
@Controller("injections")
export class InjectionController {
  constructor(private readonly injections: InjectionService) {}

  /** 内置生物制剂协议列表 */
  @Get("protocols")
  protocols() {
    return listProtocols();
  }

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.injections.list(user.userId, patientId);
  }

  @Get("upcoming")
  upcoming(
    @CurrentUser() user: JwtUser,
    @Query("patientId") patientId?: string,
    @Query("withinDays") withinDays?: string,
  ) {
    return this.injections.upcoming(
      user.userId,
      patientId,
      withinDays ? Number(withinDays) : 30,
    );
  }

  /** 按协议生成完整排期 */
  @Post("schedule")
  generate(@CurrentUser() user: JwtUser, @Body() body: GenerateScheduleInput) {
    return this.injections.generateSchedule(user.userId, body);
  }

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateInjectionDto) {
    return this.injections.create(user.userId, dto);
  }

  /** 记录实际注射并顺延后续计划 */
  @Post(":id/complete")
  complete(
    @CurrentUser() user: JwtUser,
    @Param("id") id: string,
    @Body() body: { actualDate?: string; rescheduleDelay?: boolean },
  ) {
    return this.injections.complete(user.userId, id, body);
  }
}
