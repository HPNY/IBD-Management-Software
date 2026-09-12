import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { PatientEntity } from "./patient.entity";

@Entity("parse_jobs")
@Index(["patientId", "createdAt"])
export class ParseJobEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "uuid" })
  patientId: string;

  @ManyToOne(() => PatientEntity, { onDelete: "CASCADE" })
  patient: PatientEntity;

  @Column({ type: "varchar", length: 512 })
  objectKey: string;

  @Column({ type: "varchar", length: 128, nullable: true })
  hospitalHint: string | null;

  @Column({ type: "varchar", length: 32, default: "queued" })
  status: "queued" | "running" | "awaiting_review" | "done" | "failed";

  @Column({ type: "varchar", length: 128, nullable: true })
  skillVersionId: string | null;

  @Column({ type: "jsonb", nullable: true })
  items: unknown[] | null;

  @Column({ type: "text", nullable: true })
  error: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
