import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { CreateMedicationDto, MedicationService } from "./medication.service";

@ApiTags("medication")
@ApiBearerAuth()
@Controller("medications")
export class MedicationController {
  constructor(private readonly meds: MedicationService) {}

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.meds.list(user.userId, patientId);
  }

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateMedicationDto) {
    return this.meds.create(user.userId, dto);
  }
}
