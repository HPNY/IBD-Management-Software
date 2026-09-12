import { Controller, Get, Param } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { PatientService } from "./patient.service";

@ApiTags("patient")
@Controller("patients")
export class PatientController {
  constructor(private readonly patients: PatientService) {}

  @Get(":id")
  get(@Param("id") id: string) {
    return this.patients.getBasic(id);
  }
}
