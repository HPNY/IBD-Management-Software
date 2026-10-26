import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * T2：parse_jobs.engine 持久化解析引擎（skill|ai）。
 * 可空列，向后兼容：历史行为 NULL，来源判定走兼容回退（见 parse-source.ts）。
 */
export class AddParseJobEngine1727600000000 implements MigrationInterface {
  name = "AddParseJobEngine1727600000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "parse_jobs" ADD "engine" character varying(16) NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "parse_jobs" DROP COLUMN "engine"`);
  }
}
