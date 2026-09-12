/**
 * 用 pg-mem 验证实体映射与 Lab/症状写入（本机无 Docker/Postgres 时的替代验收）。
 * 运行: pnpm --filter @ibd/api smoke:entities
 */
import "reflect-metadata";
import { randomUUID } from "node:crypto";
import { newDb, DataType } from "pg-mem";
import { DataSource } from "typeorm";
import { entities } from "../src/database/entities";

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
  db.public.registerFunction({
    name: "gen_random_uuid",
    returns: DataType.uuid,
    implementation: () => randomUUID(),
  });

  const ds: DataSource = await db.adapters.createTypeormDataSource({
    type: "postgres",
    entities,
    synchronize: true,
  });
  await ds.initialize();

  const users = ds.getRepository(entities.find((e) => e.name === "UserEntity")!);
  const patients = ds.getRepository(entities.find((e) => e.name === "PatientEntity")!);
  const labs = ds.getRepository(entities.find((e) => e.name === "LabResultEntity")!);
  const symptoms = ds.getRepository(entities.find((e) => e.name === "SymptomDiaryEntity")!);

  const user = await users.save(users.create({ phone: "smoke" }));
  const patient = await patients.save(
    patients.create({
      userId: user.id,
      name: "smoke",
      sex: "male",
      birthDate: "1990-01-01",
      diagnosisDate: "2022-12-01",
      ibdType: "crohns",
    }),
  );

  const lab = await labs.save(
    labs.create({
      patientId: patient.id,
      date: "2026-01-15",
      hospital: "示例三甲医院A",
      source: "manual",
      deviceId: "dev1",
      hlcWallMs: String(Date.now()),
      hlcCounter: 0,
      items: [
        {
          nameNorm: "超敏C反应蛋白",
          nameRaw: "hs-CRP",
          value: 2.2,
          unit: "mg/L",
          refMin: 0,
          refMax: 5,
          flag: null,
        },
      ] as never,
    }),
  );

  const diary = await symptoms.save(
    symptoms.create({
      patientId: patient.id,
      date: "2026-01-15",
      painLevel: 2,
      diarrheaCount: 3,
      stoolType: 6,
    }),
  );

  const loaded = await labs.findOne({ where: { id: lab.id }, relations: ["items"] });
  if (!loaded || loaded.items.length !== 1 || loaded.items[0].value !== 2.2) {
    throw new Error("lab items cascade failed");
  }
  if (!diary.id) throw new Error("symptom diary save failed");

  console.log(
    JSON.stringify(
      {
        ok: true,
        patientId: patient.id,
        labId: lab.id,
        labItem: loaded.items[0].nameNorm,
        symptomId: diary.id,
      },
      null,
      2,
    ),
  );

  await ds.destroy();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
