import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { SymptomService, UpsertSymptomDto } from "./symptom.service";

@ApiTags("symptom")
@ApiBearerAuth()
@Controller("symptoms")
export class SymptomController {
  constructor(private readonly symptoms: SymptomService) {}

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.symptoms.list(user.userId, patientId);
  }

  @Post()
  upsert(@CurrentUser() user: JwtUser, @Body() dto: UpsertSymptomDto) {
    return this.symptoms.upsert(user.userId, dto);
  }
}
