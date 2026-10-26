/**
 * 在 pg-mem 上执行 InitSchema raw SQL，并做一次插入。
 * 运行: pnpm --filter @ibd/api smoke:migration
 */
import "reflect-metadata";
import { randomUUID } from "node:crypto";
import { newDb, DataType } from "pg-mem";
import { DataSource } from "typeorm";
import { InitSchema1726200000000 } from "../src/database/migrations/1726200000000-InitSchema";
import { AddParseJobEngine1727600000000 } from "../src/database/migrations/1727600000000-AddParseJobEngine";

async function main() {
  const db = newDb({ autoCreateForeignKeyIndices: true });
  db.public.registerFunction({
    name: "current_database",
    returns: DataType.text,
    implementation: () => "ibd",
  });
  db.public.registerFunction({
    name: "version",
    returns: DataType.text,
    implementation: () => "PostgreSQL 16.0 (pg-mem)",
  });
  db.public.registerFunction({
    name: "uuid_generate_v4",
    returns: DataType.uuid,
    implementation: () => randomUUID(),
  });

  const ds: DataSource = await db.adapters.createTypeormDataSource({
    type: "postgres",
    synchronize: false,
  });
  await ds.initialize();

  const runner = ds.createQueryRunner();
  const origQuery = runner.query.bind(runner);
  runner.query = async (sql: string, params?: unknown[]) => {
    if (/create\s+extension/i.test(sql)) return [];
    return origQuery(sql, params);
  };

  await new InitSchema1726200000000().up(runner);

  const tables = await runner.query(
    `SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`,
  );
  const names = (tables as Array<{ table_name: string }>).map((t) => t.table_name);
  const required = [
    "users",
    "devices",
    "patients",
    "lab_results",
    "lab_items",
    "medications",
    "injections",
    "symptom_diaries",
    "parse_jobs",
    "reminder_rules",
  ];
  const missing = required.filter((t) => !names.includes(t));
  if (missing.length) throw new Error(`missing tables: ${missing.join(",")}`);

  // T2：parse_jobs.engine 迁移可执行且可空（向后兼容）。
  // 行为级探针：缺省 engine 插入不报错且回读为 NULL——pg-mem 对 ALTER 加列的
  // is_nullable 目录表示与真 PG 有差异，真 PG 行为由迁移 DDL 的显式 NULL 保证。
  await new AddParseJobEngine1727600000000().up(runner);
  const engineCols = await runner.query(
    `SELECT column_name FROM information_schema.columns WHERE table_name='parse_jobs' AND column_name='engine'`,
  );
  if (!engineCols.length) throw new Error("parse_jobs.engine column missing");
  const probeUserId = randomUUID();
  await runner.query(
    `INSERT INTO users (id, phone, status) VALUES ($1, $2, $3)`,
    [probeUserId, "engine-probe-user", "active"],
  );
  const probePatientId = randomUUID();
  await runner.query(
    `INSERT INTO patients (id, "userId", name, sex, "birthDate", "diagnosisDate", "ibdType")
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [probePatientId, probeUserId, "probe", "unknown", "2000-01-01", "2020-01-01", "cd"],
  );
  await runner.query(
    `INSERT INTO parse_jobs (id, "patientId", "objectKey", "status") VALUES ($1, $2, $3, $4)`,
    [randomUUID(), probePatientId, "inline://probe", "done"],
  );
  const probeRows = (await runner.query(
    `SELECT engine FROM parse_jobs WHERE "patientId"=$1`,
    [probePatientId],
  )) as Array<{ engine: string | null }>;
  if (!probeRows.length) throw new Error("engine probe insert failed");
  if (probeRows[0].engine !== null) {
    throw new Error("parse_jobs.engine must default to NULL for legacy rows");
  }

  await runner.query(`INSERT INTO users (phone, status) VALUES ($1, $2)`, [
    "mig-smoke",
    "active",
  ]);
  const users = await runner.query(`SELECT phone FROM users WHERE phone=$1`, ["mig-smoke"]);
  if (!users.length) throw new Error("insert into migrated users failed");

  // 关联插入：user → patient → lab_result → lab_items
  const user = await runner.query(`SELECT id FROM users WHERE phone=$1`, ["mig-smoke"]);
  await runner.query(
    `INSERT INTO patients ("userId", name, sex, "birthDate", "diagnosisDate", "ibdType")
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [user[0].id, "mig", "male", "1990-01-01", "2022-12-01", "crohns"],
  );
  const patient = await runner.query(`SELECT id FROM patients LIMIT 1`);
  await runner.query(
    `INSERT INTO lab_results ("patientId", date, "deviceId", "hlcWallMs", "hlcCounter")
     VALUES ($1,$2,$3,$4,$5)`,
    [patient[0].id, "2026-01-01", "dev", "1", 0],
  );
  const lab = await runner.query(`SELECT id FROM lab_results LIMIT 1`);
  await runner.query(
    `INSERT INTO lab_items ("labResultId", "nameNorm", "nameRaw", value)
     VALUES ($1,$2,$3,$4)`,
    [lab[0].id, "超敏C反应蛋白", "hs-CRP", 2.1],
  );

  const item = await runner.query(`SELECT "nameNorm", value FROM lab_items LIMIT 1`);
  console.log(
    JSON.stringify(
      { ok: true, tables: names, labItem: item[0] },
      null,
      2,
    ),
  );

  await runner.release();
  await ds.destroy();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
