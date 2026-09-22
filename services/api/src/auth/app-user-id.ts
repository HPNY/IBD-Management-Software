import { ForbiddenException } from "@nestjs/common";
import type { JwtUser } from "./types";

/**
 * 以 JWT 内身份为准解析 appUserId。
 * 客户端可回显 body/query 中的 appUserId，但不一致时拒绝——防止用 A 的会话操作 B。
 */
export function resolveAppUserId(
  user: JwtUser,
  claimed?: string | null,
): string {
  const bound = user.appUserId || user.userId;
  const claim = claimed?.trim();
  if (claim && claim !== bound && claim !== user.userId) {
    throw new ForbiddenException("appUserId mismatch");
  }
  return bound;
}
