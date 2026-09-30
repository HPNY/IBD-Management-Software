import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Param,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { Public } from "../../auth/public.decorator";
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

  @Public()
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

  @Public()
  @Post("login")
  login(@Body() body: { email: string; password: string }) {
    return this.auth.login(body.email, body.password);
  }

  @ApiBearerAuth()
  @UseGuards(RequireScope("doctor"))
  @Get("me")
  async me(@Req() req: { user?: DoctorJwt & JwtUser }) {
    const d = await this.auth.me(
      (req.user as { doctorId?: string })?.doctorId ??
        req.user?.userId ??
        "",
    );
    if (!d) return null;
    // 不回传 passwordHash
    return {
      id: d.id,
      name: d.name,
      email: d.email,
      hospital: d.hospital,
      licenseNo: d.licenseNo,
      reviewStatus: d.reviewStatus,
    };
  }

  /** 人工审核：需管理令牌（避免任意用户批准医生）。 */
  @Public()
  @Post(":id/approve")
  approve(
    @Param("id") id: string,
    @Body() body: { status: "approved" | "rejected" },
    @Headers("x-admin-token") adminToken?: string,
  ) {
    const expect = process.env.DOCTOR_ADMIN_TOKEN || "dev-doctor-admin";
    if (!adminToken || adminToken !== expect) {
      throw new UnauthorizedException("admin token required");
    }
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
    @Body() body: { code: string; wrappedDek?: string; scope?: string[] },
    @Req() req: { user?: JwtUser },
  ) {
    return this.grants.confirm(req.user?.userId ?? "", body.code, {
      wrappedDek: body.wrappedDek,
      scope: body.scope,
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
