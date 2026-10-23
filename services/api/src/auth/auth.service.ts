import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { InjectRepository } from "@nestjs/typeorm";
import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { Repository } from "typeorm";
import { DevicePubKeyEntity, RefreshTokenEntity, UserEntity } from "../database/entities";
import {
  newNonce,
  publicKeyFingerprint,
  sessionSignPayload,
  verifyEd25519,
} from "./device-pop";
import type { JwtUser } from "./types";

/** 开发环境固定验证码；生产应接短信服务商。 */
const DEV_SMS_CODE = process.env.DEV_SMS_CODE ?? "123456";
/** H2：开发短信登录须显式开启（ENABLE_DEV_SMS_LOGIN=true），非 production 也默认关闭，
 *  避免 demo/staging 误暴露 123456 后门。production 由 env-guard 强制禁用。 */
const DEV_SMS_LOGIN_ENABLED = process.env.ENABLE_DEV_SMS_LOGIN === "true";
const IS_PROD =
  (process.env.NODE_ENV ?? "development").toLowerCase() === "production";
const ACCESS_TTL = process.env.JWT_ACCESS_TTL ?? "15m";
const REFRESH_TTL_DAYS = Number(process.env.JWT_REFRESH_TTL_DAYS ?? 30);

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: string;
  tokenType: "Bearer";
  user: { id: string; phone: string | null; status: string };
}

/** 短会话签发入参；H3 持有证明三元组可选（REQUIRE_POP=true 时必填）。 */
export interface SessionIssueInput {
  appUserId: string;
  deviceId?: string;
  devicePubKey?: string;
  popNonce?: string;
  popSignature?: string;
}

export interface SessionIssueResult {
  accessToken: string;
  expiresIn: string;
  tokenType: "Bearer";
  scope: string;
  appUserId: string;
  nonce: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly jwt: JwtService,
    @InjectRepository(UserEntity)
    private readonly users: Repository<UserEntity>,
    @InjectRepository(RefreshTokenEntity)
    private readonly refreshTokens: Repository<RefreshTokenEntity>,
    @InjectRepository(DevicePubKeyEntity)
    private readonly devicePubKeys: Repository<DevicePubKeyEntity>,
  ) {}

  async loginWithPhone(input: {
    phone: string;
    code: string;
    deviceId?: string;
  }): Promise<TokenPair> {
    if (!input.phone || !/^\d{6,20}$/.test(input.phone)) {
      throw new BadRequestException("invalid phone");
    }
    // H2：生产始终禁用开发固定码短信登录；非生产须显式 ENABLE_DEV_SMS_LOGIN=true。
    if (IS_PROD) {
      throw new UnauthorizedException("sms login disabled in production");
    }
    if (!DEV_SMS_LOGIN_ENABLED) {
      throw new UnauthorizedException(
        "sms login disabled: set ENABLE_DEV_SMS_LOGIN=true for local/dev testing",
      );
    }
    // timing-safe 比对，避免验证码时序侧信道。
    const codeBuf = Buffer.from(input.code ?? "", "utf8");
    const expBuf = Buffer.from(DEV_SMS_CODE, "utf8");
    const codeMatches =
      codeBuf.length === expBuf.length && timingSafeEqual(codeBuf, expBuf);
    if (!codeMatches) {
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
   * 会在 users 表登记一条 session 用户，保证 patient.userId 外键可用。
   */
  async issueParseSession(
    input: SessionIssueInput,
  ): Promise<SessionIssueResult> {
    return this.issueScopedSession("parse_session", "30m", input);
  }

  async issueSyncSession(
    input: SessionIssueInput,
  ): Promise<SessionIssueResult> {
    return this.issueScopedSession("sync_ciphertext", "15m", input);
  }

  /** 推送注册短时会话（scope=push_register）：只绑 appUserId，无登录墙 */
  async issuePushSession(
    input: SessionIssueInput,
  ): Promise<SessionIssueResult> {
    return this.issueScopedSession("push_register", "15m", input);
  }

  async issueCommunitySession(
    input: SessionIssueInput,
  ): Promise<SessionIssueResult> {
    return this.issueScopedSession("community", "30m", input);
  }

  /**
   * H3（DPoP-lite）统一短会话签发：验签设备持有证明 → 登记/更新公钥 → JWT 内嵌 popKeyHash。
   * REQUIRE_POP=true 时强制要求 PoP；默认（渐进迁移）允许缺省以兼容旧客户端/e2e。
   */
  private async issueScopedSession(
    scope: "parse_session" | "sync_ciphertext" | "push_register" | "community",
    expiresIn: string,
    input: SessionIssueInput,
  ): Promise<SessionIssueResult> {
    const user = await this.ensureSessionUser(input.appUserId);
    const requirePop = process.env.REQUIRE_POP === "true";

    // H3 持有证明：验签 appUserId|nonce，登记公钥并把指纹写入 JWT。
    let popKeyHash: string | undefined;
    if (input.devicePubKey && input.popNonce && input.popSignature) {
      const data = sessionSignPayload(input.appUserId, input.popNonce);
      if (!verifyEd25519(input.devicePubKey, data, input.popSignature)) {
        throw new UnauthorizedException("invalid device proof-of-possession");
      }
      popKeyHash = publicKeyFingerprint(input.devicePubKey);
      await this.registerDevicePubKey(input.appUserId, input.devicePubKey, popKeyHash);
    } else if (requirePop) {
      throw new UnauthorizedException("device proof-of-possession required");
    }

    const accessToken = this.jwt.sign(
      {
        userId: user.id,
        deviceId: input.deviceId,
        scope,
        appUserId: input.appUserId,
        ...(popKeyHash ? { popKeyHash } : {}),
      },
      { expiresIn: expiresIn as `${number}m` },
    );
    return {
      accessToken,
      expiresIn,
      tokenType: "Bearer",
      scope,
      appUserId: input.appUserId,
      nonce: newNonce(),
    };
  }

  /** 登记/轮换设备公钥（同 appUserId 唯一）。 */
  private async registerDevicePubKey(
    appUserId: string,
    publicKey: string,
    pubKeyHash: string,
  ): Promise<void> {
    const existing = await this.devicePubKeys.findOne({ where: { appUserId } });
    const now = new Date();
    if (existing) {
      await this.devicePubKeys.save({
        ...existing,
        publicKey,
        pubKeyHash,
        lastSeenAt: now,
      });
    } else {
      await this.devicePubKeys.save(
        this.devicePubKeys.create({
          appUserId,
          publicKey,
          pubKeyHash,
          createdAt: now,
          lastSeenAt: now,
        }),
      );
    }
  }

  private async ensureSessionUser(appUserId: string): Promise<UserEntity> {
    if (!appUserId || appUserId.length < 8) {
      throw new BadRequestException("appUserId required");
    }
    const existing = await this.users.findOne({
      where: { wechatOpenId: appUserId },
    });
    if (existing) return existing;
    return this.users.save(
      this.users.create({ wechatOpenId: appUserId, status: "active" }),
    );
  }

  private hash(token: string): string {
    return createHash("sha256").update(token).digest("hex");
  }
}