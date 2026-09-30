import { MigrationInterface, QueryRunner } from "typeorm";

/** T6.2 M3/M4：医生建议与审计日志。 */
export class AddDoctorNotesAudit1727300000000 implements MigrationInterface {
  name = "AddDoctorNotesAudit1727300000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "doctor_notes" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "grantId" uuid NOT NULL,
        "doctorId" uuid NOT NULL,
        "patientId" uuid NOT NULL,
        "anchorDate" character varying(10),
        "content" character varying(500) NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_doctor_notes" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_doctor_notes_patient" ON "doctor_notes" ("patientId")`,
    );
    await queryRunner.query(`
      CREATE TABLE "doctor_audit_logs" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "doctorId" uuid NOT NULL,
        "patientId" uuid NOT NULL,
        "action" character varying(32) NOT NULL,
        "resourceId" character varying(64),
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_doctor_audit_logs" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_doctor_audit_patient" ON "doctor_audit_logs" ("patientId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_doctor_audit_patient"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "doctor_audit_logs"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_doctor_notes_patient"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "doctor_notes"`);
  }
}
