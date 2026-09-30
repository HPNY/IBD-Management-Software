import { MigrationInterface, QueryRunner } from "typeorm";

/** 对齐 App：症状日记补 bowelCount/urgency/mucus（供医生端摘要）。 */
export class AddSymptomBowelFields1727400000000
  implements MigrationInterface
{
  name = "AddSymptomBowelFields1727400000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "symptom_diaries" ADD "bowelCount" integer`,
    );
    await queryRunner.query(
      `ALTER TABLE "symptom_diaries" ADD "urgency" boolean`,
    );
    await queryRunner.query(
      `ALTER TABLE "symptom_diaries" ADD "mucus" boolean`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "symptom_diaries" DROP COLUMN "mucus"`,
    );
    await queryRunner.query(
      `ALTER TABLE "symptom_diaries" DROP COLUMN "urgency"`,
    );
    await queryRunner.query(
      `ALTER TABLE "symptom_diaries" DROP COLUMN "bowelCount"`,
    );
  }
}
