import { MigrationInterface, QueryRunner } from "typeorm";

/** 用完即删：parse_jobs.sourceDeleted */
export class AddParseSourceDeleted1726900000000 implements MigrationInterface {
  name = "AddParseSourceDeleted1726900000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "parse_jobs" ADD "sourceDeleted" boolean NOT NULL DEFAULT false`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "parse_jobs" DROP COLUMN "sourceDeleted"`,
    );
  }
}
