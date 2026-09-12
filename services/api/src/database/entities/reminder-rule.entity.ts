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

@Entity("reminder_rules")
@Index(["patientId", "kind"])
export class ReminderRuleEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "uuid" })
  patientId: string;

  @ManyToOne(() => PatientEntity, { onDelete: "CASCADE" })
  patient: PatientEntity;

  @Column({ type: "varchar", length: 32 })
  kind: "injection" | "medication" | "followup";

  @Column({ type: "int", default: 3 })
  leadDays: number;

  @Column({ type: "boolean", default: true })
  enabled: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
