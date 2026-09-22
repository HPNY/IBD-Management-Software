import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { resolveAppUserId } from "../../auth/app-user-id";
import { CurrentUser } from "../../auth/current-user.decorator";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";
import { PushService } from "./push.service";

@ApiTags("push")
@ApiBearerAuth()
@Controller("push")
export class PushController {
  constructor(private readonly push: PushService) {}

  /** 注册设备令牌（只绑 JWT 内 appUserId；scope: full 或 push_register） */
  @UseGuards(RequireScope("full", "push_register"))
  @Post("devices")
  register(
    @CurrentUser() user: JwtUser,
    @Body()
    body: {
      appUserId?: string;
      token: string;
      platform?: string;
    },
  ) {
    const appUserId = resolveAppUserId(user, body.appUserId);
    return this.push.register({
      appUserId,
      token: body.token,
      platform: body.platform,
    });
  }

  /** 注销：token 单条；否则按 appUserId 清空 */
  @UseGuards(RequireScope("full", "push_register"))
  @Delete("devices")
  unregister(
    @CurrentUser() user: JwtUser,
    @Body()
    body: { appUserId?: string; token?: string },
    @Query("appUserId") q?: string,
    @Query("token") qToken?: string,
  ) {
    const appUserId = resolveAppUserId(user, body?.appUserId || q);
    const token = body?.token || qToken;
    return this.push.unregister({ appUserId, token });
  }

  /** 查看当前绑定的令牌（只回前缀，不回完整 token） */
  @UseGuards(RequireScope("full", "push_register"))
  @Get("devices")
  async list(
    @CurrentUser() user: JwtUser,
    @Query("appUserId") q?: string,
  ) {
    const appUserId = resolveAppUserId(user, q);
    const rows = await this.push.listForUser(appUserId);
    return {
      count: rows.length,
      devices: rows.map((r) => ({
        id: r.id,
        platform: r.platform,
        tokenPrefix: r.token.slice(0, 12),
        lastSeenAt: r.lastSeenAt,
        createdAt: r.createdAt,
      })),
    };
  }

  /**
   * 触发一条通用提醒（测试 / 定时任务入口）。
   * 只发「您有一条用药提醒」等通用文案，不携带临床数据。
   */
  @UseGuards(RequireScope("full", "push_register"))
  @Post("notify")
  notify(
    @CurrentUser() user: JwtUser,
    @Body() body: { appUserId?: string; kind?: string },
  ) {
    const appUserId = resolveAppUserId(user, body?.appUserId);
    return this.push.notifyUser({ appUserId, kind: body?.kind });
  }
}
