import "reflect-metadata";
import { DataSource, DataSourceOptions } from "typeorm";
import { entities } from "./entities";

export const dataSourceOptions: DataSourceOptions = {
  type: "postgres",
  url: process.env.DATABASE_URL ?? "postgres://ibd:ibd@localhost:5432/ibd",
  entities,
  // 生产/开发默认走 migrations；仅本地无库冒烟可用 DB_SYNC=true（不推荐）
  synchronize: process.env.DB_SYNC === "true",
  migrationsRun: process.env.DB_MIGRATIONS_RUN === "true",
  migrationsTableName: "typeorm_migrations",
  migrations: [__dirname + "/migrations/*.{js,ts}"],
  logging: process.env.DB_LOGGING === "true",
};

const dataSource = new DataSource(dataSourceOptions);
export default dataSource;
