import { MigrationInterface, QueryRunner } from "typeorm";

/** D2/D3：药物评价与同城帖表（此前仅实体注册，缺迁移）。 */
export class AddDrugReviewAndGeoPosts1727100000000
  implements MigrationInterface
{
  name = "AddDrugReviewAndGeoPosts1727100000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "drug_review_submissions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "drugName" character varying(128) NOT NULL,
        "ibdType" character varying(8) NOT NULL DEFAULT 'unknown',
        "efficacy" integer NOT NULL,
        "seSideEffect" integer NOT NULL,
        "sideEffectTypes" jsonb,
        "stillUsing" boolean NOT NULL DEFAULT true,
        "comment" character varying(500),
        "raterHash" character varying(64) NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_drug_review_submissions" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_drug_review_drug_rater" ON "drug_review_submissions" ("drugName", "raterHash")`,
    );
    await queryRunner.query(`
      CREATE TABLE "geo_posts" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "city" character varying(64) NOT NULL,
        "nickname" character varying(64) NOT NULL,
        "content" character varying(500) NOT NULL,
        "authorHash" character varying(64) NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_geo_posts" PRIMARY KEY ("id")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "geo_posts"`);
    await queryRunner.query(
      `DROP INDEX IF EXISTS "UQ_drug_review_drug_rater"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "drug_review_submissions"`);
  }
}
