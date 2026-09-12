import { Controller, Get } from "@nestjs/common";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";

@Controller("health")
export class HealthController {
  constructor(
    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  @Get()
  async check() {
    let db = "down";
    try {
      await this.dataSource.query("SELECT 1");
      db = "ok";
    } catch {
      db = "down";
    }
    return {
      status: db === "ok" ? "ok" : "degraded",
      service: "ibd-api",
      db,
      time: new Date().toISOString(),
    };
  }
}
