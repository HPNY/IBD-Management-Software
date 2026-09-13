import { Controller, Get, Param } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { PatientService } from "./patient.service";

@ApiTags("patient")
@ApiBearerAuth()
@Controller("patients")
export class PatientController {
  constructor(private readonly patients: PatientService) {}

  /** 当前登录用户档案（无则创建默认） */
  @Get("me")
  me(@CurrentUser() user: JwtUser) {
    return this.patients.ensurePatientForUser(user.userId);
  }

  @Get(":id")
  get(@Param("id") id: string) {
    return this.patients.getBasic(id);
  }
}
