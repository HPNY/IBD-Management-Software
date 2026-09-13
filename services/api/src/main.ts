import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { DataSource } from "typeorm";
import { AppModule } from "./app.module";
import { PatientService } from "./modules/patient/patient.service";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.setGlobalPrefix("api/v1", { exclude: ["health"] });
  app.enableCors({ origin: true });

  const config = new DocumentBuilder()
    .setTitle("肠安通 IBD API")
    .setVersion("0.1.0")
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup("docs", app, document);

  // 默认启动跑 migrations；设 RUN_MIGRATIONS=false 可关
  if (process.env.RUN_MIGRATIONS !== "false") {
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

  try {
    await app.get(PatientService).ensureDemoPatient();
  } catch {
    // eslint-disable-next-line no-console
    console.warn("demo patient seed skipped (DB unavailable?)");
  }

  // eslint-disable-next-line no-console
  console.log(`API listening on :${port}`);
}

bootstrap();
