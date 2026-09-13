import { MigrationInterface, QueryRunner } from "typeorm";

export class AddParseSkills1726400000000 implements MigrationInterface {
  name = "AddParseSkills1726400000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "parse_skills" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "hospital" character varying(128) NOT NULL,
        "reportType" character varying(64) NOT NULL,
        "currentVersion" character varying(64),
        "createdById" uuid,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_parse_skills" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_parse_skills_hospital_type" UNIQUE ("hospital", "reportType"),
        CONSTRAINT "FK_parse_skills_user" FOREIGN KEY ("createdById")
          REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "parse_skill_versions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "skillId" uuid NOT NULL,
        "version" character varying(64) NOT NULL,
        "content" jsonb NOT NULL,
        "source" character varying(32) NOT NULL DEFAULT 'ai_generated',
        "accuracy" double precision,
        "usageCount" integer NOT NULL DEFAULT 0,
        "sharedToCommunity" boolean NOT NULL DEFAULT false,
        "createdById" uuid,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_parse_skill_versions" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_skill_version" UNIQUE ("skillId", "version"),
        CONSTRAINT "FK_skill_versions_skill" FOREIGN KEY ("skillId")
          REFERENCES "parse_skills"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);

    await queryRunner.query(
      `ALTER TABLE "parse_jobs" ADD "reportType" character varying(64)`,
    );
    await queryRunner.query(
      `ALTER TABLE "parse_jobs" ADD "reportDate" date`,
    );
    await queryRunner.query(
      `ALTER TABLE "parse_jobs" ADD "confirmedItems" jsonb`,
    );
    await queryRunner.query(
      `ALTER TABLE "parse_jobs" ADD "confirmedAt" TIMESTAMP`,
    );
    await queryRunner.query(
      `ALTER TABLE "parse_jobs" ADD "labResultId" uuid`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const col of ["reportType", "reportDate", "confirmedItems", "confirmedAt", "labResultId"]) {
      await queryRunner.query(`ALTER TABLE "parse_jobs" DROP COLUMN "${col}"`);
    }
    await queryRunner.query(`DROP TABLE IF EXISTS "parse_skill_versions" CASCADE`);
    await queryRunner.query(`DROP TABLE IF EXISTS "parse_skills" CASCADE`);
  }
}
