import { DataSourceOptions } from "typeorm";
import { entities } from "./entities";

const url = process.env.DATABASE_URL ?? "postgres://ibd:ibd@localhost:5432/ibd";
const synchronize = process.env.DB_SYNC !== "false";

export const dataSourceOptions: DataSourceOptions = {
  type: "postgres",
  url,
  entities,
  // 骨架阶段 synchronize；上线前改为 migrations。
  synchronize,
  logging: process.env.DB_LOGGING === "true",
};
