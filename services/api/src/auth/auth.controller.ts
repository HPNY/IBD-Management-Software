import { Body, Controller, Get, Post } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
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

  @ApiBearerAuth()
  @Get("me")
  me(@CurrentUser() user: JwtUser) {
    return this.auth.me(user.userId);
  }
}
