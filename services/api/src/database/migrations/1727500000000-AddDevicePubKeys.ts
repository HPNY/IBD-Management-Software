import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * H3（DPoP-lite）：device_pubkeys 表，登记设备 Ed25519 公钥用于持有证明。
 */
export class AddDevicePubKeys1727500000000 implements MigrationInterface {
  name = "AddDevicePubKeys1727500000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "device_pubkeys" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "appUserId" character varying(64) NOT NULL,
        "publicKey" text NOT NULL,
        "pubKeyHash" character varying(32) NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "lastSeenAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_device_pubkeys" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_device_pubkeys_appUserId" ON "device_pubkeys" ("appUserId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_device_pubkeys_appUserId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "device_pubkeys" CASCADE`);
  }
}
