import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { MedicationEntity } from "./medication.entity";

@Entity("adverse_events")
@Index(["medicationId", "occurredAt"])
export class AdverseEventEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  medicationId: string;

  @ManyToOne(() => MedicationEntity, { onDelete: "CASCADE" })
  medication: MedicationEntity;

  /** 带状疱疹、反复感染等 */
  @Column({ type: "varchar", length: 128 })
  title: string;

  @Column({ type: "varchar", length: 16, default: "mild" })
  severity: "mild" | "moderate" | "severe";

  @Column({ type: "date" })
  occurredAt: string;

  @Column({ type: "text", nullable: true })
  notes: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
