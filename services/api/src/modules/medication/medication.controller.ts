import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { MedicationRecord, MedicationService } from "./medication.service";

@ApiTags("medication")
@Controller("medications")
export class MedicationController {
  constructor(private readonly meds: MedicationService) {}

  @Get()
  list(@Query("patientId") patientId = "demo") {
    return this.meds.list(patientId);
  }

  @Post()
  create(@Body() dto: Omit<MedicationRecord, "id">) {
    return this.meds.create(dto);
  }
}
