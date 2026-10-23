import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { DataSource } from "typeorm";
import { AppModule } from "./app.module";
import { assertSafeRuntimeConfig } from "./config/env-guard";

async function bootstrap() {
  assertSafeRuntimeConfig();

  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.setGlobalPrefix("api/v1", { exclude: ["health"] });
  const isProd = (process.env.NODE_ENV ?? "").toLowerCase() === "production";
  // H1：CORS 收敛为显式白名单（CORS_ORIGINS 逗号分隔）；未配置则仅同源，不再反射任意 Origin。
  const corsOrigins = (process.env.CORS_ORIGINS ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  app.enableCors({ origin: corsOrigins.length ? corsOrigins : false });

  // H1：Swagger 仅在非生产挂载，生产不暴露 API 文档面。
  if (!isProd) {
    const config = new DocumentBuilder()
      .setTitle("IBDers IBD API")
      .setVersion("0.1.0")
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup("docs", app, document);
  }

  // 生产默认不自动迁移；需显式 RUN_MIGRATIONS=true（或独立 Job）
  const runMigrations =
    process.env.RUN_MIGRATIONS === "true" ||
    (!isProd && process.env.RUN_MIGRATIONS !== "false");

  if (runMigrations) {
    try {
      const ds = app.get(DataSource);
      const executed = await ds.runMigrations({ transaction: "each" });
      // eslint-disable-next-line no-console
      console.log(
        executed.length
          ? `migrations applied: ${executed.map((m) => m.name).join(", ")}`
          : "migrations up to date",
      );
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("migration run failed", err);
      throw err;
    }
  }

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`API listening on :${port}`);
}

bootstrap();