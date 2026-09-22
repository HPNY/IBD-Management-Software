import { MigrationInterface, QueryRunner } from "typeorm";

export class AddDeviceTokens1726800000000 implements MigrationInterface {
  name = "AddDeviceTokens1726800000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "device_tokens" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "appUserId" character varying(64) NOT NULL,
        "token" character varying(512) NOT NULL,
        "platform" character varying(32) NOT NULL DEFAULT 'unknown',
        "lastSeenAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_device_tokens" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_device_tokens_token" UNIQUE ("token")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_device_tokens_appUserId" ON "device_tokens" ("appUserId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "device_tokens" CASCADE`);
  }
}
