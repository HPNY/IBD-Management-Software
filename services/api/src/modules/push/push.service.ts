import { BadRequestException, Injectable, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { DeviceTokenEntity } from "../../database/entities";
import {
  FcmService,
  normalizePushKind,
  PushKind,
  SendPushResult,
} from "./fcm.service";

export interface RegisterDeviceInput {
  appUserId: string;
  token: string;
  platform?: string;
}

export interface NotifyInput {
  appUserId: string;
  kind?: string;
}

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(
    @InjectRepository(DeviceTokenEntity)
    private readonly tokens: Repository<DeviceTokenEntity>,
    private readonly fcm: FcmService,
  ) {}

  /** 注册/更新设备令牌：只绑 appUserId，无登录墙。 */
  async register(input: RegisterDeviceInput) {
    const appUserId = input.appUserId?.trim();
    const token = input.token?.trim();
    if (!appUserId || appUserId.length < 8) {
      throw new BadRequestException("appUserId required");
    }
    if (!token || token.length < 8) {
      throw new BadRequestException("token required");
    }
    const platform = (input.platform ?? "unknown").slice(0, 32);
    const existing = await this.tokens.findOne({ where: { token } });
    const now = new Date();
    if (existing) {
      existing.appUserId = appUserId;
      existing.platform = platform;
      existing.lastSeenAt = now;
      await this.tokens.save(existing);
      return {
        id: existing.id,
        appUserId,
        platform,
        fcmConfigured: this.fcm.configured,
        mode: this.fcm.configured ? "fcm" : "dry-run",
      };
    }
    const row = await this.tokens.save(
      this.tokens.create({
        appUserId,
        token,
        platform,
        lastSeenAt: now,
      }),
    );
    this.logger.log(
      `device registered appUserId=${appUserId.slice(0, 8)}… platform=${platform}`,
    );
    return {
      id: row.id,
      appUserId,
      platform,
      fcmConfigured: this.fcm.configured,
      mode: this.fcm.configured ? "fcm" : "dry-run",
    };
  }

  /**
   * 注销：传 token 删单条；只传 appUserId 删该用户全部令牌。
   * 可随时调用，与是否登录无关。
   */
  async unregister(input: { appUserId: string; token?: string }) {
    const appUserId = input.appUserId?.trim();
    const token = input.token?.trim();
    if (!appUserId && !token) {
      throw new BadRequestException("appUserId or token required");
    }
    if (token) {
      const res = await this.tokens.delete({ token });
      return { deleted: res.affected ?? 0 };
    }
    const res = await this.tokens.delete({ appUserId });
    this.logger.log(
      `devices wiped appUserId=${appUserId.slice(0, 8)}… n=${res.affected ?? 0}`,
    );
    return { deleted: res.affected ?? 0 };
  }

  async listForUser(appUserId: string) {
    return this.tokens.find({ where: { appUserId } });
  }

  /**
   * 向某用户的已注册设备发通用提醒。
   * payload 仅 title/body 通用文案 + kind 路由，无药品/剂量/病历。
   */
  async notifyUser(input: NotifyInput): Promise<{
    kind: PushKind;
    dryRun: boolean;
    targets: number;
    results: SendPushResult[];
  }> {
    const appUserId = input.appUserId?.trim();
    if (!appUserId) {
      throw new BadRequestException("appUserId required");
    }
    const kind = normalizePushKind(input.kind);
    const rows = await this.tokens.find({ where: { appUserId } });
    const results: SendPushResult[] = [];
    for (const row of rows) {
      // 本地占位令牌（local-）不是 FCM token，真发时跳过，避免无效调用
      if (this.fcm.configured && row.token.startsWith("local-")) {
        results.push({
          ok: true,
          dryRun: true,
          tokenPrefix: row.token.slice(0, 12),
        });
        continue;
      }
      results.push(
        await this.fcm.send({ token: row.token, kind, platform: row.platform }),
      );
    }
    return {
      kind,
      dryRun: !this.fcm.configured,
      targets: rows.length,
      results,
    };
  }
}
