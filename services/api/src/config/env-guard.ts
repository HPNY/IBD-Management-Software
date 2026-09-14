/**
 * 启动前配置校验：production 下禁止危险默认值。
 * 由 main.ts 在 Nest 启动前调用。
 */
export function assertSafeRuntimeConfig(env: NodeJS.ProcessEnv = process.env): void {
  const nodeEnv = (env.NODE_ENV ?? "development").toLowerCase();
  const isProd = nodeEnv === "production";
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isProd) {
    if (errors.length) throw new Error(errors.join("\n"));
    return;
  }

  // 1) 开发验证码禁止带入生产
  const sms = env.DEV_SMS_CODE ?? "123456";
  if (sms === "123456" || sms === "dev" || sms.length < 6) {
    errors.push(
      "DEV_SMS_CODE must not be the development default when NODE_ENV=production",
    );
  }

  // 2) 禁止 TypeORM synchronize
  if (env.DB_SYNC === "true") {
    errors.push("DB_SYNC=true is forbidden when NODE_ENV=production");
  }

  // 3) 存储签名密钥
  const storageSecret = env.STORAGE_SECRET ?? "";
  if (!storageSecret || storageSecret === "dev-storage-secret") {
    errors.push(
      "STORAGE_SECRET must be set to a non-default value in production",
    );
  }

  // 4) JWT
  const jwtSecret = env.JWT_SECRET ?? "";
  if (!jwtSecret || jwtSecret === "dev-jwt-secret-change-me") {
    errors.push("JWT_SECRET must be set to a non-default value in production");
  }

  // 5) PUBLIC_BASE_URL
  const base = (env.PUBLIC_BASE_URL ?? "").toLowerCase();
  if (!base) {
    errors.push("PUBLIC_BASE_URL is required in production");
  } else if (base.includes("localhost") || base.includes("127.0.0.1")) {
    errors.push(
      "PUBLIC_BASE_URL must not use localhost/127.0.0.1 in production",
    );
  } else if (base.startsWith("http://") && !base.includes("127.0.0.1")) {
    warnings.push("PUBLIC_BASE_URL uses http:// in production; prefer https://");
  }

  // 6) 数据库 URL 密码强度（弱口令）
  const dbUrl = env.DATABASE_URL ?? "";
  if (/postgres:\/\/[^:]+:(ibd|password|postgres|test)@/i.test(dbUrl)) {
    warnings.push(
      "DATABASE_URL appears to use a weak/dev password in production",
    );
  }

  for (const w of warnings) {
    // eslint-disable-next-line no-console
    console.warn(`[config] WARNING: ${w}`);
  }

  if (errors.length) {
    throw new Error(
      `[config] Refusing to start in production:\n- ${errors.join("\n- ")}`,
    );
  }
}
