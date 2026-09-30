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

/** MVP：症状日记；独立排便流水 BathroomRecord 属 V1.0。 */
@Entity("symptom_diaries")
@Index(["patientId", "date"], { unique: true })
export class SymptomDiaryEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "uuid" })
  patientId: string;

  @ManyToOne(() => PatientEntity, { onDelete: "CASCADE" })
  patient: PatientEntity;

  @Column({ type: "date" })
  date: string;

  @Column({ type: "int", nullable: true })
  painLevel: number | null;

  @Column({ type: "int", nullable: true })
  diarrheaCount: number | null;

  @Column({ type: "int", nullable: true })
  stoolType: number | null;

  @Column({ type: "varchar", length: 16, nullable: true })
  bloodyStool: "none" | "trace" | "obvious" | null;

  @Column({ type: "int", nullable: true })
  bloating: number | null;

  @Column({ type: "int", nullable: true })
  fatigue: number | null;

  @Column({ type: "boolean", nullable: true })
  nausea: boolean | null;

  @Column({ type: "varchar", length: 16, nullable: true })
  overallFeeling: "better" | "same" | "worse" | null;

  /** G2 排便细项（对齐 App 本地库，供摘要） */
  @Column({ type: "int", nullable: true })
  bowelCount: number | null;

  @Column({ type: "boolean", nullable: true })
  urgency: boolean | null;

  @Column({ type: "boolean", nullable: true })
  mucus: boolean | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
