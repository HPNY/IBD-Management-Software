import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * H2：云备份增加 KDF 盐列。
 * 旧快照该列为 NULL，客户端按 appUserId 派生（兼容）；新快照写入随机盐，
 * 换机/重装后 appUserId 变化仍可解密。
 */
export class AddSyncSnapshotKdfSalt1727700000000 implements MigrationInterface {
  name = "AddSyncSnapshotKdfSalt1727700000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "sync_snapshots" ADD "kdfSalt" text NULL`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "sync_snapshots" DROP COLUMN "kdfSalt"`);
  }
}
