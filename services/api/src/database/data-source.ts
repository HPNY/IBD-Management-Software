import "reflect-metadata";
import { DataSource, DataSourceOptions } from "typeorm";
import { entities } from "./entities";

const isProd =
  (process.env.NODE_ENV ?? "development").toLowerCase() === "production";

export const dataSourceOptions: DataSourceOptions = {
  type: "postgres",
  url: process.env.DATABASE_URL ?? "postgres://ibd:ibd@localhost:5432/ibd",
  entities,
  // 仅非生产且显式 DB_SYNC=true 时允许；生产强制 false
  synchronize: !isProd && process.env.DB_SYNC === "true",
  migrationsRun: process.env.DB_MIGRATIONS_RUN === "true",
  migrationsTableName: "typeorm_migrations",
  migrations: [__dirname + "/migrations/*.{js,ts}"],
  logging: process.env.DB_LOGGING === "true",
};

const dataSource = new DataSource(dataSourceOptions);
export default dataSource;
