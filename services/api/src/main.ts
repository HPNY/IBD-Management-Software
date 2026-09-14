import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { DataSource } from "typeorm";
import { AppModule } from "./app.module";
import { assertSafeRuntimeConfig } from "./config/env-guard";

async function bootstrap() {
  assertSafeRuntimeConfig();

  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.setGlobalPrefix("api/v1", { exclude: ["health"] });
  app.enableCors({ origin: true });

  const config = new DocumentBuilder()
    .setTitle("IBDers IBD API")
    .setVersion("0.1.0")
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup("docs", app, document);

  const isProd = (process.env.NODE_ENV ?? "").toLowerCase() === "production";
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
