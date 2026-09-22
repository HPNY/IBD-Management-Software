import { createSign } from "node:crypto";
import { Injectable, Logger } from "@nestjs/common";

export type PushKind = "medication" | "injection" | "followup" | "system";

/** 仅通用文案；payload 禁止携带药品/剂量/病历。 */
export const GENERIC_PUSH_COPY: Record<
  PushKind,
  { title: string; body: string }
> = {
  medication: { title: "IBDers", body: "您有一条用药提醒" },
  injection: { title: "IBDers", body: "您有一条注射提醒" },
  followup: { title: "IBDers", body: "您有一条复查提醒" },
  system: { title: "IBDers", body: "您有一条系统通知" },
};

export function normalizePushKind(kind?: string): PushKind {
  if (
    kind === "medication" ||
    kind === "injection" ||
    kind === "followup" ||
    kind === "system"
  ) {
    return kind;
  }
  return "system";
}

export interface SendPushInput {
  token: string;
  kind: PushKind;
  platform?: string;
}

export interface SendPushResult {
  ok: boolean;
  dryRun: boolean;
  messageId?: string;
  error?: string;
  tokenPrefix: string;
}

/**
 * FCM 发送：配置 FCM_* 才真实发送，否则 dry-run（只记日志）。
 * 配置二选一：
 *  - 服务账号：FCM_PROJECT_ID + FCM_CLIENT_EMAIL + FCM_PRIVATE_KEY
 *  - 传统密钥：FCM_SERVER_KEY
 */
@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private accessTokenCache: { token: string; expiresAt: number } | null = null;

  get configured(): boolean {
    return Boolean(this.serverKey || this.serviceAccountReady);
  }

  private get serverKey(): string | undefined {
    const v = process.env.FCM_SERVER_KEY?.trim();
    return v && v.length > 0 ? v : undefined;
  }

  private get projectId(): string | undefined {
    return process.env.FCM_PROJECT_ID?.trim() || undefined;
  }

  private get clientEmail(): string | undefined {
    return process.env.FCM_CLIENT_EMAIL?.trim() || undefined;
  }

  private get privateKey(): string | undefined {
    const raw = process.env.FCM_PRIVATE_KEY;
    if (!raw) return undefined;
    // 支持 .env 中的 \n 转义
    return raw.replace(/\\n/g, "\n");
  }

  private get serviceAccountReady(): boolean {
    return Boolean(this.projectId && this.clientEmail && this.privateKey);
  }

  async send(input: SendPushInput): Promise<SendPushResult> {
    const kind = normalizePushKind(input.kind);
    const copy = GENERIC_PUSH_COPY[kind];
    const tokenPrefix = input.token.slice(0, 12);
    // 永远只发通用 title/body；data 仅 kind 路由，无临床字段
    const payload = {
      title: copy.title,
      body: copy.body,
      data: { kind },
    };

    if (!this.configured) {
      this.logger.log(
        `[dry-run] push kind=${kind} token=${tokenPrefix}… title=${payload.title} body=${payload.body}`,
      );
      return { ok: true, dryRun: true, tokenPrefix };
    }

    try {
      if (this.serverKey) {
        return await this.sendLegacy(input.token, payload, tokenPrefix);
      }
      return await this.sendV1(input.token, payload, tokenPrefix);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error(`push failed token=${tokenPrefix}… ${message}`);
      return { ok: false, dryRun: false, error: message, tokenPrefix };
    }
  }

  private async sendLegacy(
    token: string,
    payload: { title: string; body: string; data: Record<string, string> },
    tokenPrefix: string,
  ): Promise<SendPushResult> {
    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `key=${this.serverKey}`,
      },
      body: JSON.stringify({
        to: token,
        priority: "high",
        notification: { title: payload.title, body: payload.body },
        data: payload.data,
      }),
    });
    const text = await res.text();
    if (!res.ok) {
      return {
        ok: false,
        dryRun: false,
        error: `legacy ${res.status} ${text.slice(0, 200)}`,
        tokenPrefix,
      };
    }
    this.logger.log(`push sent (legacy) token=${tokenPrefix}…`);
    return { ok: true, dryRun: false, tokenPrefix };
  }

  private async sendV1(
    token: string,
    payload: { title: string; body: string; data: Record<string, string> },
    tokenPrefix: string,
  ): Promise<SendPushResult> {
    const accessToken = await this.getAccessToken();
    const project = this.projectId!;
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: payload.title, body: payload.body },
            data: payload.data,
          },
        }),
      },
    );
    const text = await res.text();
    if (!res.ok) {
      return {
        ok: false,
        dryRun: false,
        error: `v1 ${res.status} ${text.slice(0, 200)}`,
        tokenPrefix,
      };
    }
    this.logger.log(`push sent (v1) token=${tokenPrefix}…`);
    return { ok: true, dryRun: false, tokenPrefix };
  }

  private async getAccessToken(): Promise<string> {
    const now = Date.now();
    if (
      this.accessTokenCache &&
      this.accessTokenCache.expiresAt - 60_000 > now
    ) {
      return this.accessTokenCache.token;
    }
    const iat = Math.floor(now / 1000);
    const exp = iat + 3600;
    const header = { alg: "RS256", typ: "JWT" };
    const claims = {
      iss: this.clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat,
      exp,
    };
    const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;
    const signer = createSign("RSA-SHA256");
    signer.update(unsigned);
    const signature = signer.sign(this.privateKey!).toString("base64url");
    const assertion = `${unsigned}.${signature}`;

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    const json = (await res.json()) as {
      access_token?: string;
      expires_in?: number;
    };
    if (!res.ok || !json.access_token) {
      throw new Error(`oauth token failed ${res.status}`);
    }
    this.accessTokenCache = {
      token: json.access_token,
      expiresAt: now + (json.expires_in ?? 3600) * 1000,
    };
    return json.access_token;
  }
}

function b64url(input: string): string {
  return Buffer.from(input).toString("base64url");
}
