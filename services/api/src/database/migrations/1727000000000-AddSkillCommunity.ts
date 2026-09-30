import { MigrationInterface, QueryRunner } from "typeorm";

/** T6.1：社区评分表 + 协作 parentVersion */
export class AddSkillCommunity1727000000000 implements MigrationInterface {
  name = "AddSkillCommunity1727000000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "parse_skill_versions" ADD "parentVersion" character varying(64)`,
    );
    await queryRunner.query(`
      CREATE TABLE "skill_ratings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "skillId" uuid NOT NULL,
        "versionId" uuid,
        "raterHash" character varying(64) NOT NULL,
        "score" integer NOT NULL,
        "comment" character varying(500),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_skill_ratings" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_skill_ratings_skill_rater" ON "skill_ratings" ("skillId", "raterHash")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_skill_ratings_skill_rater"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "skill_ratings"`);
    await queryRunner.query(
      `ALTER TABLE "parse_skill_versions" DROP COLUMN "parentVersion"`,
    );
  }
}
