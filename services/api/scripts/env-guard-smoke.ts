/**
 * env-guard 单元冒烟：pnpm --filter @ibd/api smoke:env
 */
import { assertSafeRuntimeConfig } from "../src/config/env-guard";

function expectThrow(name: string, env: NodeJS.ProcessEnv) {
  try {
    assertSafeRuntimeConfig(env);
    throw new Error(`${name}: expected throw`);
  } catch (e) {
    if (String(e).includes("expected throw")) throw e;
    console.log(`OK ${name}`);
  }
}

function expectPass(name: string, env: NodeJS.ProcessEnv) {
  assertSafeRuntimeConfig(env);
  console.log(`OK ${name}`);
}

// development 不检查
expectPass("dev-defaults-ok", { NODE_ENV: "development" });

expectThrow("prod-dev-sms", {
  NODE_ENV: "production",
  DEV_SMS_CODE: "123456",
  DB_SYNC: "false",
  STORAGE_SECRET: "strong-secret-value",
  JWT_SECRET: "strong-jwt-secret-value",
  PUBLIC_BASE_URL: "https://ibders.example.com",
});

expectThrow("prod-db-sync", {
  NODE_ENV: "production",
  DEV_SMS_CODE: "998877",
  DB_SYNC: "true",
  STORAGE_SECRET: "strong-secret-value",
  JWT_SECRET: "strong-jwt-secret-value",
  PUBLIC_BASE_URL: "https://ibders.example.com",
});

expectThrow("prod-localhost-base", {
  NODE_ENV: "production",
  DEV_SMS_CODE: "998877",
  DB_SYNC: "false",
  STORAGE_SECRET: "strong-secret-value",
  JWT_SECRET: "strong-jwt-secret-value",
  PUBLIC_BASE_URL: "http://localhost:3000",
});

expectThrow("prod-default-storage", {
  NODE_ENV: "production",
  DEV_SMS_CODE: "998877",
  DB_SYNC: "false",
  STORAGE_SECRET: "dev-storage-secret",
  JWT_SECRET: "strong-jwt-secret-value",
  PUBLIC_BASE_URL: "https://ibders.example.com",
});

expectPass("prod-ok", {
  NODE_ENV: "production",
  DEV_SMS_CODE: "998877",
  DB_SYNC: "false",
  STORAGE_SECRET: "strong-secret-value",
  JWT_SECRET: "strong-jwt-secret-value",
  PUBLIC_BASE_URL: "https://ibders.example.com",
  DATABASE_URL: "postgres://ibd:strong-pass@db:5432/ibd",
});

console.log("ALL_PASS");
