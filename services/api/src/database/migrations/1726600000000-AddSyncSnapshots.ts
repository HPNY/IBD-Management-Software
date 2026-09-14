import { MigrationInterface, QueryRunner } from "typeorm";

export class AddSyncSnapshots1726600000000 implements MigrationInterface {
  name = "AddSyncSnapshots1726600000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "sync_snapshots" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "appUserId" character varying(64) NOT NULL,
        "dataType" character varying(32) NOT NULL,
        "cipher" text NOT NULL,
        "nonce" text NOT NULL,
        "version" bigint NOT NULL DEFAULT 1,
        "clientUpdatedAt" TIMESTAMPTZ NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_sync_snapshots" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_sync_app_type" UNIQUE ("appUserId", "dataType")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_sync_snapshots_appUserId" ON "sync_snapshots" ("appUserId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "sync_snapshots" CASCADE`);
  }
}
