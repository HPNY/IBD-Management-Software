import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from "typeorm";

/** T6.2 M3.3：医生医学建议。 */
@Entity("doctor_notes")
export class DoctorNoteEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  grantId: string;

  @Column({ type: "uuid" })
  doctorId: string;

  @Column({ type: "uuid" })
  patientId: string;

  @Column({ type: "varchar", length: 10, nullable: true })
  anchorDate: string | null;

  @Column({ type: "varchar", length: 500 })
  content: string;

  @CreateDateColumn()
  createdAt: Date;
}

/** T6.2 M4.1：医生访问审计。 */
@Entity("doctor_audit_logs")
export class DoctorAuditLogEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  doctorId: string;

  @Column({ type: "uuid" })
  patientId: string;

  @Column({ type: "varchar", length: 32 })
  action: string;

  @Column({ type: "varchar", length: 64, nullable: true })
  resourceId: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
