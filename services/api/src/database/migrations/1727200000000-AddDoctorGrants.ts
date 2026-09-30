import { MigrationInterface, QueryRunner } from "typeorm";

/** T6.2 M1/M2：医生账号与授权 Grant。 */
export class AddDoctorGrants1727200000000 implements MigrationInterface {
  name = "AddDoctorGrants1727200000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "doctors" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" character varying(128) NOT NULL,
        "email" character varying(128) NOT NULL,
        "passwordHash" character varying(256) NOT NULL,
        "hospital" character varying(128),
        "licenseNo" character varying(64),
        "reviewStatus" character varying(16) NOT NULL DEFAULT 'pending',
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_doctors" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_doctors_email" UNIQUE ("email")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "doctor_grants" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "doctorId" uuid NOT NULL,
        "patientId" uuid NOT NULL,
        "scope" jsonb NOT NULL,
        "code" character varying(64) NOT NULL,
        "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "revokedAt" TIMESTAMP WITH TIME ZONE,
        "wrappedDek" text,
        "confirmed" boolean NOT NULL DEFAULT false,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_doctor_grants" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_doctor_grants_code" UNIQUE ("code")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_doctor_grants_patient" ON "doctor_grants" ("patientId")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_doctor_grants_doctor" ON "doctor_grants" ("doctorId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_doctor_grants_doctor"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_doctor_grants_patient"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "doctor_grants"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "doctors"`);
  }
}
