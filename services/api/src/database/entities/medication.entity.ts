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

@Entity("medications")
@Index(["patientId", "status"])
export class MedicationEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "uuid" })
  patientId: string;

  @ManyToOne(() => PatientEntity, { onDelete: "CASCADE" })
  patient: PatientEntity;

  @Column({ type: "varchar", length: 128 })
  drugName: string;

  @Column({ type: "varchar", length: 128, nullable: true })
  brandName: string | null;

  @Column({ type: "varchar", length: 64, nullable: true })
  category: string | null;

  @Column({ type: "varchar", length: 64 })
  dosage: string;

  @Column({ type: "varchar", length: 64 })
  frequency: string;

  @Column({ type: "varchar", length: 16 })
  route: "oral" | "sc" | "iv";

  @Column({ type: "date" })
  startDate: string;

  @Column({ type: "date", nullable: true })
  endDate: string | null;

  @Column({ type: "varchar", length: 16, default: "active" })
  status: "active" | "paused" | "stopped";

  @Column({ type: "text", nullable: true })
  reason: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
