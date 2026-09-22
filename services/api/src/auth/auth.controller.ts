import {
  Body,
  Controller,
  Get,
  HttpException,
  HttpStatus,
  Post,
  Req,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import type { Request } from "express";
import { clientIp, sessionMintLimiter } from "../common/rate-limit";
import { AuthService } from "./auth.service";
import { CurrentUser } from "./current-user.decorator";
import { Public } from "./public.decorator";
import type { JwtUser } from "./types";

@ApiTags("auth")
@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** 开发环境验证码默认 123456（DEV_SMS_CODE） */
  @Public()
  @Post("login")
  login(
    @Body()
    body: {
      phone: string;
      code: string;
      deviceId?: string;
    },
  ) {
    return this.auth.loginWithPhone(body);
  }

  @Public()
  @Post("refresh")
  refresh(@Body() body: { refreshToken: string; deviceId?: string }) {
    return this.auth.refresh(body.refreshToken, body.deviceId);
  }

  @Public()
  @Post("logout")
  logout(@Body() body: { refreshToken: string }) {
    return this.auth.logout(body.refreshToken);
  }

  /** 本地优先：无登录解析会话（短时，仅 parse 相关） */
  @Public()
  @Post("parse-session")
  parseSession(
    @Body() body: { appUserId: string; deviceId?: string },
    @Req() req: Request,
  ) {
    this.throttleMint(req, body.appUserId);
    return this.auth.issueParseSession(body) as Promise<unknown>;
  }

  /** 密文同步短时会话 */
  @Public()
  @Post("sync-session")
  syncSession(
    @Body() body: { appUserId: string; deviceId?: string },
    @Req() req: Request,
  ) {
    this.throttleMint(req, body.appUserId);
    return this.auth.issueSyncSession(body) as Promise<unknown>;
  }

  /** 推送设备注册短时会话（无登录墙） */
  @Public()
  @Post("push-session")
  pushSession(
    @Body() body: { appUserId: string; deviceId?: string },
    @Req() req: Request,
  ) {
    this.throttleMint(req, body.appUserId);
    return this.auth.issuePushSession(body) as Promise<unknown>;
  }

  @ApiBearerAuth()
  @Get("me")
  me(@CurrentUser() user: JwtUser) {
    return this.auth.me(user.userId);
  }

  /** 短时会话签发限流：同 IP+appUserId，防刷能力凭证 */
  private throttleMint(req: Request, appUserId?: string) {
    const key = `${clientIp(req)}|${appUserId ?? ""}`;
    const d = sessionMintLimiter.take(key);
    if (!d.ok) {
      throw new HttpException(
        { message: "too many session requests", retryAfterSec: d.retryAfterSec },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }
}
