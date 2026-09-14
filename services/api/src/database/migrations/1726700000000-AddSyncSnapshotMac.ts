import { MigrationInterface, QueryRunner } from "typeorm";

export class AddSyncSnapshotMac1726700000000 implements MigrationInterface {
  name = "AddSyncSnapshotMac1726700000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "sync_snapshots" ADD "mac" text`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "sync_snapshots" DROP COLUMN "mac"`,
    );
  }
}
