import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from "typeorm";
import { PatientEntity } from "./patient.entity";
import { LabItemEntity } from "./lab-item.entity";

@Entity("lab_results")
@Index(["patientId", "date"])
export class LabResultEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "uuid" })
  patientId: string;

  @ManyToOne(() => PatientEntity, { onDelete: "CASCADE" })
  patient: PatientEntity;

  @Column({ type: "date" })
  date: string;

  @Column({ type: "varchar", length: 128, nullable: true })
  hospital: string | null;

  @Column({ type: "varchar", length: 16, default: "manual" })
  source: "skill" | "ai" | "manual";

  @Column({ type: "varchar", length: 128 })
  deviceId: string;

  @Column({ type: "bigint" })
  hlcWallMs: string;

  @Column({ type: "int", default: 0 })
  hlcCounter: number;

  @OneToMany(() => LabItemEntity, (item) => item.labResult, {
    cascade: true,
    eager: true,
  })
  items: LabItemEntity[];

  @CreateDateColumn()
  createdAt: Date;
}
