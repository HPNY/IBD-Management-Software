import { MigrationInterface, QueryRunner } from "typeorm";

export class AddAdverseEvents1726500000000 implements MigrationInterface {
  name = "AddAdverseEvents1726500000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "adverse_events" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "medicationId" uuid NOT NULL,
        "title" character varying(128) NOT NULL,
        "severity" character varying(16) NOT NULL DEFAULT 'mild',
        "occurredAt" date NOT NULL,
        "notes" text,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_adverse_events" PRIMARY KEY ("id"),
        CONSTRAINT "FK_adverse_medication" FOREIGN KEY ("medicationId")
          REFERENCES "medications"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_adverse_med_date" ON "adverse_events" ("medicationId", "occurredAt")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "adverse_events" CASCADE`);
  }
}
