import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";
import {
  DoctorAuthService,
  DoctorGrantService,
  DoctorJwt,
} from "./doctor.service";

@ApiTags("doctor")
@Controller("doctor")
export class DoctorController {
  constructor(private readonly auth: DoctorAuthService) {}

  @Post("register")
  register(
    @Body()
    body: {
      name: string;
      email: string;
      password: string;
      hospital?: string;
      licenseNo?: string;
    },
  ) {
    return this.auth.register(body);
  }

  @Post("login")
  login(@Body() body: { email: string; password: string }) {
    return this.auth.login(body.email, body.password);
  }

  @ApiBearerAuth()
  @UseGuards(RequireScope("doctor"))
  @Get("me")
  me(@Req() req: { user?: DoctorJwt }) {
    return this.auth.me(req.user?.doctorId ?? req.user?.userId ?? "");
  }

  /** 人工审核（占位；生产应加管理端）。 */
  @Post(":id/approve")
  approve(
    @Param("id") id: string,
    @Body() body: { status: "approved" | "rejected" },
  ) {
    return this.auth.approve(id, body.status);
  }
}

@ApiTags("doctor-grant")
@ApiBearerAuth()
@Controller("doctor-grants")
export class DoctorGrantController {
  constructor(private readonly grants: DoctorGrantService) {}

  /** 医生：生成授权码 */
  @UseGuards(RequireScope("doctor"))
  @Post("code")
  createCode(
    @Body() body: { scope: string[]; ttlHours?: number },
    @Req() req: { user?: DoctorJwt },
  ) {
    return this.grants.createCode({
      doctorId: req.user?.doctorId ?? req.user?.userId ?? "",
      scope: body.scope,
      ttlHours: body.ttlHours,
    });
  }

  /** 患者：扫码确认 */
  @UseGuards(RequireScope("full", "doctor_grant"))
  @Post("confirm")
  confirm(
    @Body() body: { code: string; wrappedDek?: string },
    @Req() req: { user?: JwtUser },
  ) {
    return this.grants.confirm(req.user?.userId ?? "", body.code, {
      wrappedDek: body.wrappedDek,
    });
  }

  /** 患者：我的授权 */
  @UseGuards(RequireScope("full", "doctor_grant"))
  @Get("mine")
  mine(@Req() req: { user?: JwtUser }) {
    return this.grants.listForPatient(req.user?.userId ?? "");
  }

  /** 患者：收回 */
  @UseGuards(RequireScope("full", "doctor_grant"))
  @Post(":id/revoke")
  revoke(@Param("id") id: string, @Req() req: { user?: JwtUser }) {
    return this.grants.revoke(req.user?.userId ?? "", id);
  }
}
