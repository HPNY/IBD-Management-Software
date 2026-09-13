import { SetMetadata } from "@nestjs/common";

export const IS_PUBLIC_KEY = "isPublic";

/** 免登录路由（登录、健康检查等）。 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
