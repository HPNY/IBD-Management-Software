import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { SymptomService, UpsertSymptomDto } from "./symptom.service";

@ApiTags("symptom")
@Controller("symptoms")
export class SymptomController {
  constructor(private readonly symptoms: SymptomService) {}

  @Get()
  list(@Query("patientId") patientId?: string) {
    return this.symptoms.list(patientId);
  }

  @Post()
  upsert(@Body() dto: UpsertSymptomDto) {
    return this.symptoms.upsert(dto);
  }
}
