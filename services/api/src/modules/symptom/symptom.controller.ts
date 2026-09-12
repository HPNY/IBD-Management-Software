import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { SymptomDiaryRecord, SymptomService } from "./symptom.service";

@ApiTags("symptom")
@Controller("symptoms")
export class SymptomController {
  constructor(private readonly symptoms: SymptomService) {}

  @Get()
  list(@Query("patientId") patientId = "demo") {
    return this.symptoms.list(patientId);
  }

  @Post()
  upsert(@Body() dto: SymptomDiaryRecord) {
    return this.symptoms.upsert(dto);
  }
}
