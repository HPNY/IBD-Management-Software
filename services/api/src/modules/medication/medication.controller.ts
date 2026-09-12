import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { CreateMedicationDto, MedicationService } from "./medication.service";

@ApiTags("medication")
@Controller("medications")
export class MedicationController {
  constructor(private readonly meds: MedicationService) {}

  @Get()
  list(@Query("patientId") patientId?: string) {
    return this.meds.list(patientId);
  }

  @Post()
  create(@Body() dto: CreateMedicationDto) {
    return this.meds.create(dto);
  }
}
