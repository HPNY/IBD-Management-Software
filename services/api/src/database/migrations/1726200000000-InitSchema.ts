import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * 初始 schema：对齐 services/api/src/database/entities/*
 * 使用 raw SQL，列名与实体属性一致（未用 snake_case naming strategy）。
 */
export class InitSchema1726200000000 implements MigrationInterface {
  name = "InitSchema1726200000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    await queryRunner.query(`
      CREATE TABLE "users" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "phone" character varying(64),
        "wechatOpenId" character varying(128),
        "status" character varying(64) NOT NULL DEFAULT 'active',
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_users" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_users_phone" UNIQUE ("phone"),
        CONSTRAINT "UQ_users_wechatOpenId" UNIQUE ("wechatOpenId")
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "devices" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "userId" uuid NOT NULL,
        "deviceId" character varying(128) NOT NULL,
        "platform" character varying(64) NOT NULL DEFAULT 'unknown',
        "lastSeenAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_devices" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_devices_user_device" UNIQUE ("userId", "deviceId"),
        CONSTRAINT "FK_devices_user" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_devices_userId" ON "devices" ("userId")`);

    await queryRunner.query(`
      CREATE TABLE "patients" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "userId" uuid NOT NULL,
        "name" character varying(64) NOT NULL,
        "sex" character varying(16) NOT NULL,
        "birthDate" date NOT NULL,
        "diagnosisDate" date NOT NULL,
        "ibdType" character varying(16) NOT NULL,
        "caseNumber" character varying(64),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_patients" PRIMARY KEY ("id"),
        CONSTRAINT "FK_patients_user" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_patients_userId" ON "patients" ("userId")`);

    await queryRunner.query(`
      CREATE TABLE "lab_results" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "patientId" uuid NOT NULL,
        "date" date NOT NULL,
        "hospital" character varying(128),
        "source" character varying(16) NOT NULL DEFAULT 'manual',
        "deviceId" character varying(128) NOT NULL,
        "hlcWallMs" bigint NOT NULL,
        "hlcCounter" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_lab_results" PRIMARY KEY ("id"),
        CONSTRAINT "FK_lab_results_patient" FOREIGN KEY ("patientId")
          REFERENCES "patients"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_lab_results_patient_date" ON "lab_results" ("patientId", "date")`);

    await queryRunner.query(`
      CREATE TABLE "lab_items" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "labResultId" uuid NOT NULL,
        "nameNorm" character varying(128) NOT NULL,
        "nameRaw" character varying(128) NOT NULL,
        "value" double precision NOT NULL,
        "unit" character varying(32),
        "refMin" double precision,
        "refMax" double precision,
        "flag" character varying(8),
        CONSTRAINT "PK_lab_items" PRIMARY KEY ("id"),
        CONSTRAINT "FK_lab_items_result" FOREIGN KEY ("labResultId")
          REFERENCES "lab_results"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_lab_items_result_name" ON "lab_items" ("labResultId", "nameNorm")`);

    await queryRunner.query(`
      CREATE TABLE "medications" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "patientId" uuid NOT NULL,
        "drugName" character varying(128) NOT NULL,
        "brandName" character varying(128),
        "category" character varying(64),
        "dosage" character varying(64) NOT NULL,
        "frequency" character varying(64) NOT NULL,
        "route" character varying(16) NOT NULL,
        "startDate" date NOT NULL,
        "endDate" date,
        "status" character varying(16) NOT NULL DEFAULT 'active',
        "reason" text,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_medications" PRIMARY KEY ("id"),
        CONSTRAINT "FK_medications_patient" FOREIGN KEY ("patientId")
          REFERENCES "patients"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_medications_patient_status" ON "medications" ("patientId", "status")`);

    await queryRunner.query(`
      CREATE TABLE "injections" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "patientId" uuid NOT NULL,
        "drug" character varying(128) NOT NULL,
        "plannedDate" date NOT NULL,
        "actualDate" date,
        "phase" character varying(16) NOT NULL,
        "dose" character varying(64) NOT NULL,
        "route" character varying(8) NOT NULL,
        "weekNumber" integer NOT NULL,
        "notes" text,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_injections" PRIMARY KEY ("id"),
        CONSTRAINT "FK_injections_patient" FOREIGN KEY ("patientId")
          REFERENCES "patients"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_injections_patient_planned" ON "injections" ("patientId", "plannedDate")`);

    await queryRunner.query(`
      CREATE TABLE "symptom_diaries" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "patientId" uuid NOT NULL,
        "date" date NOT NULL,
        "painLevel" integer,
        "diarrheaCount" integer,
        "stoolType" integer,
        "bloodyStool" character varying(16),
        "bloating" integer,
        "fatigue" integer,
        "nausea" boolean,
        "overallFeeling" character varying(16),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_symptom_diaries" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_symptom_patient_date" UNIQUE ("patientId", "date"),
        CONSTRAINT "FK_symptom_patient" FOREIGN KEY ("patientId")
          REFERENCES "patients"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "parse_jobs" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "patientId" uuid NOT NULL,
        "objectKey" character varying(512) NOT NULL,
        "hospitalHint" character varying(128),
        "status" character varying(32) NOT NULL DEFAULT 'queued',
        "skillVersionId" character varying(128),
        "items" jsonb,
        "error" text,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_parse_jobs" PRIMARY KEY ("id"),
        CONSTRAINT "FK_parse_jobs_patient" FOREIGN KEY ("patientId")
          REFERENCES "patients"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_parse_jobs_patient_created" ON "parse_jobs" ("patientId", "createdAt")`);

    await queryRunner.query(`
      CREATE TABLE "reminder_rules" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "patientId" uuid NOT NULL,
        "kind" character varying(32) NOT NULL,
        "leadDays" integer NOT NULL DEFAULT 3,
        "enabled" boolean NOT NULL DEFAULT true,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_reminder_rules" PRIMARY KEY ("id"),
        CONSTRAINT "FK_reminder_patient" FOREIGN KEY ("patientId")
          REFERENCES "patients"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_reminder_patient_kind" ON "reminder_rules" ("patientId", "kind")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const table of [
      "reminder_rules",
      "parse_jobs",
      "symptom_diaries",
      "injections",
      "medications",
      "lab_items",
      "lab_results",
      "patients",
      "devices",
      "users",
    ]) {
      await queryRunner.query(`DROP TABLE IF EXISTS "${table}" CASCADE`);
    }
  }
}
