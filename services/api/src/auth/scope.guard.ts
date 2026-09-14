import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";
import type { JwtUser } from "./types";

/** 仅允许特定 token scope 访问（parse_session / sync_ciphertext / full）。 */
export function RequireScope(...allowed: Array<NonNullable<JwtUser["scope"]>>) {
  @Injectable()
  class ScopeGuard implements CanActivate {
    canActivate(context: ExecutionContext): boolean {
      const req = context
        .switchToHttp()
        .getRequest<{ user?: JwtUser }>();
      const scope = req.user?.scope ?? "full";
      if (!allowed.includes(scope)) {
        throw new ForbiddenException(`scope ${scope} not allowed`);
      }
      return true;
    }
  }
  return ScopeGuard;
}
