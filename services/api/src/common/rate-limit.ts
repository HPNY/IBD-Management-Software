/**
 * 进程内滑动窗口限流（单实例 MVP）。
 * 按 key（IP / appUserId）计数；多实例部署时请换 Redis/网关限流。
 */
export interface RateLimitDecision {
  ok: boolean;
  remaining: number;
  retryAfterSec: number;
}

export class RateLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
  ) {}

  /** 记一次命中；超出则拒绝并给出建议重试秒数。 */
  take(key: string, now = Date.now()): RateLimitDecision {
    const cutoff = now - this.windowMs;
    const arr = (this.hits.get(key) ?? []).filter((t) => t > cutoff);
    if (arr.length >= this.limit) {
      const oldest = arr[0];
      const retryAfterSec = Math.max(
        1,
        Math.ceil((oldest + this.windowMs - now) / 1000),
      );
      this.hits.set(key, arr);
      return { ok: false, remaining: 0, retryAfterSec };
    }
    arr.push(now);
    this.hits.set(key, arr);
    // 偶尔清理，避免 Map 无限增长
    if (this.hits.size > 5000) {
      for (const [k, v] of this.hits) {
        if (!v.some((t) => t > cutoff)) this.hits.delete(k);
      }
    }
    return {
      ok: true,
      remaining: this.limit - arr.length,
      retryAfterSec: 0,
    };
  }
}

/** 短时会话签发：同 IP+appUserId 20 次 / 分钟 */
export const sessionMintLimiter = new RateLimiter(20, 60_000);

/** 设备令牌注册/注销：同 appUserId 30 次 / 分钟 */
export const deviceTokenLimiter = new RateLimiter(30, 60_000);

/** 通用提醒触发：同 appUserId 10 次 / 分钟，防刷推送 */
export const pushNotifyLimiter = new RateLimiter(10, 60_000);

export function clientIp(req: {
  headers: Record<string, unknown>;
  socket?: { remoteAddress?: string };
  ip?: string;
}): string {
  const xff = req.headers["x-forwarded-for"];
  if (typeof xff === "string" && xff.length > 0) {
    return xff.split(",")[0]!.trim();
  }
  return req.ip || req.socket?.remoteAddress || "unknown";
}
