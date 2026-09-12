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

@Entity("injections")
@Index(["patientId", "plannedDate"])
export class InjectionEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "uuid" })
  patientId: string;

  @ManyToOne(() => PatientEntity, { onDelete: "CASCADE" })
  patient: PatientEntity;

  @Column({ type: "varchar", length: 128 })
  drug: string;

  @Column({ type: "date" })
  plannedDate: string;

  @Column({ type: "date", nullable: true })
  actualDate: string | null;

  @Column({ type: "varchar", length: 16 })
  phase: "induction" | "maintenance";

  @Column({ type: "varchar", length: 64 })
  dose: string;

  @Column({ type: "varchar", length: 8 })
  route: "sc" | "iv";

  @Column({ type: "int" })
  weekNumber: number;

  @Column({ type: "text", nullable: true })
  notes: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
