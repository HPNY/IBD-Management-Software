import { Body, Controller, Get, Param, Patch, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import {
  AdjustMedicationDto,
  CreateAdverseEventDto,
  CreateMedicationDto,
  MedicationService,
  SwitchMedicationDto,
} from "./medication.service";

@ApiTags("medication")
@ApiBearerAuth()
@Controller("medications")
export class MedicationController {
  constructor(private readonly meds: MedicationService) {}

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.meds.list(user.userId, patientId);
  }

  @Get("current")
  current(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.meds.listCurrent(user.userId, patientId);
  }

  /** 用药切换链 + 副作用时间线 */
  @Get("timeline")
  timeline(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.meds.timeline(user.userId, patientId);
  }

  @Get(":id")
  getOne(@CurrentUser() user: JwtUser, @Param("id") id: string) {
    return this.meds.getOne(user.userId, id);
  }

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateMedicationDto) {
    return this.meds.create(user.userId, dto);
  }

  @Patch(":id")
  update(
    @CurrentUser() user: JwtUser,
    @Param("id") id: string,
    @Body() dto: Partial<CreateMedicationDto>,
  ) {
    return this.meds.update(user.userId, id, dto);
  }

  /** 剂量/频次调整：关旧开新 */
  @Post(":id/adjust")
  adjust(
    @CurrentUser() user: JwtUser,
    @Param("id") id: string,
    @Body() dto: AdjustMedicationDto,
  ) {
    return this.meds.adjust(user.userId, id, dto);
  }

  @Post(":id/pause")
  pause(
    @CurrentUser() user: JwtUser,
    @Param("id") id: string,
    @Body() body: { reason?: string },
  ) {
    return this.meds.setStatus(user.userId, id, "paused", body?.reason);
  }

  @Post(":id/resume")
  resume(@CurrentUser() user: JwtUser, @Param("id") id: string) {
    return this.meds.setStatus(user.userId, id, "active", "恢复用药");
  }

  @Post(":id/stop")
  stop(
    @CurrentUser() user: JwtUser,
    @Param("id") id: string,
    @Body() body: { reason?: string; endDate?: string },
  ) {
    return this.meds.setStatus(
      user.userId,
      id,
      "stopped",
      body?.reason,
      body?.endDate,
    );
  }

  /** 换药：停旧 + 开新 */
  @Post("switch")
  switch(@CurrentUser() user: JwtUser, @Body() dto: SwitchMedicationDto) {
    return this.meds.switch(user.userId, dto);
  }

  @Post(":id/adverse-events")
  addAdverse(
    @CurrentUser() user: JwtUser,
    @Param("id") id: string,
    @Body() dto: CreateAdverseEventDto,
  ) {
    return this.meds.addAdverseEvent(user.userId, id, dto);
  }

  @Get(":id/adverse-events")
  listAdverse(@CurrentUser() user: JwtUser, @Param("id") id: string) {
    return this.meds.listAdverseEvents(user.userId, id);
  }
}
