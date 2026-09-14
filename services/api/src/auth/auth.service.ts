import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { InjectRepository } from "@nestjs/typeorm";
import { createHash, randomBytes } from "node:crypto";
import { Repository } from "typeorm";
import { RefreshTokenEntity, UserEntity } from "../database/entities";
import type { JwtUser } from "./types";

/** 开发环境固定验证码；生产应接短信服务商。 */
const DEV_SMS_CODE = process.env.DEV_SMS_CODE ?? "123456";
const ACCESS_TTL = process.env.JWT_ACCESS_TTL ?? "15m";
const REFRESH_TTL_DAYS = Number(process.env.JWT_REFRESH_TTL_DAYS ?? 30);

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: string;
  tokenType: "Bearer";
  user: { id: string; phone: string | null; status: string };
}

@Injectable()
export class AuthService {
  constructor(
    private readonly jwt: JwtService,
    @InjectRepository(UserEntity)
    private readonly users: Repository<UserEntity>,
    @InjectRepository(RefreshTokenEntity)
    private readonly refreshTokens: Repository<RefreshTokenEntity>,
  ) {}

  async loginWithPhone(input: {
    phone: string;
    code: string;
    deviceId?: string;
  }): Promise<TokenPair> {
    if (!input.phone || !/^\d{6,20}$/.test(input.phone)) {
      throw new BadRequestException("invalid phone");
    }
    // 开发桩：固定码；生产：校验短信/验证码服务
    if (input.code !== DEV_SMS_CODE) {
      throw new UnauthorizedException("invalid sms code");
    }

    let user = await this.users.findOne({ where: { phone: input.phone } });
    if (!user) {
      user = await this.users.save(
        this.users.create({ phone: input.phone, status: "active" }),
      );
    } else if (user.status !== "active") {
      throw new UnauthorizedException("user disabled");
    }

    return this.issueTokens(user, input.deviceId);
  }

  async refresh(refreshToken: string, deviceId?: string): Promise<TokenPair> {
    const tokenHash = this.hash(refreshToken);
    const row = await this.refreshTokens.findOne({ where: { tokenHash } });
    if (!row || row.revokedAt || row.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException("invalid refresh token");
    }
    // 轮转：吊销旧 token
    row.revokedAt = new Date();
    await this.refreshTokens.save(row);

    const user = await this.users.findOne({ where: { id: row.userId } });
    if (!user || user.status !== "active") {
      throw new UnauthorizedException("user not active");
    }
    return this.issueTokens(user, deviceId ?? row.deviceId ?? undefined);
  }

  async logout(refreshToken: string): Promise<{ ok: true }> {
    const tokenHash = this.hash(refreshToken);
    await this.refreshTokens.update(
      { tokenHash, revokedAt: null as never },
      { revokedAt: new Date() },
    );
    return { ok: true };
  }

  async me(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    return {
      id: user.id,
      phone: user.phone,
      status: user.status,
      createdAt: user.createdAt,
    };
  }

  private async issueTokens(user: UserEntity, deviceId?: string): Promise<TokenPair> {
    const payload: JwtUser = {
      userId: user.id,
      phone: user.phone,
      deviceId,
      scope: "full",
    };
    const accessToken = this.jwt.sign(payload, {
      expiresIn: ACCESS_TTL as `${number}m`,
    });
    const refreshToken = randomBytes(32).toString("hex");
    const expiresAt = new Date(
      Date.now() + REFRESH_TTL_DAYS * 24 * 3600 * 1000,
    );
    await this.refreshTokens.save(
      this.refreshTokens.create({
        userId: user.id,
        tokenHash: this.hash(refreshToken),
        deviceId: deviceId ?? null,
        expiresAt,
      }),
    );
    return {
      accessToken,
      refreshToken,
      expiresIn: ACCESS_TTL,
      tokenType: "Bearer",
      user: { id: user.id, phone: user.phone, status: user.status },
    };
  }

  /**
   * 解析短时会话：仅用于「同意上传」后的 PDF 解析链路，
   * 不要求长期账号；scope=parse_session。
   */
  issueParseSession(input: { appUserId: string; deviceId?: string }) {
    if (!input.appUserId || input.appUserId.length < 8) {
      throw new BadRequestException("appUserId required");
    }
    const accessToken = this.jwt.sign(
      {
        userId: input.appUserId,
        phone: null,
        deviceId: input.deviceId,
        scope: "parse_session",
        appUserId: input.appUserId,
      } satisfies JwtUser,
      { expiresIn: "30m" },
    );
    return {
      accessToken,
      expiresIn: "30m",
      tokenType: "Bearer",
      scope: "parse_session",
      appUserId: input.appUserId,
    };
  }

  /** 密文同步短时会话（scope=sync_ciphertext） */
  issueSyncSession(input: { appUserId: string; deviceId?: string }) {
    if (!input.appUserId || input.appUserId.length < 8) {
      throw new BadRequestException("appUserId required");
    }
    const accessToken = this.jwt.sign(
      {
        userId: input.appUserId,
        phone: null,
        deviceId: input.deviceId,
        scope: "sync_ciphertext",
        appUserId: input.appUserId,
      } satisfies JwtUser,
      { expiresIn: "15m" },
    );
    return {
      accessToken,
      expiresIn: "15m",
      tokenType: "Bearer",
      scope: "sync_ciphertext",
      appUserId: input.appUserId,
    };
  }

  private hash(token: string): string {
    return createHash("sha256").update(token).digest("hex");
  }
}
