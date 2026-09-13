import { Column, Entity, Index, ManyToOne, PrimaryGeneratedColumn } from "typeorm";
import { LabResultEntity } from "./lab-result.entity";

@Entity("lab_items")
@Index(["labResultId", "nameNorm"])
export class LabItemEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  labResultId: string;

  @ManyToOne(() => LabResultEntity, (r) => r.items, { onDelete: "CASCADE" })
  labResult: LabResultEntity;

  @Column({ type: "varchar", length: 128 })
  nameNorm: string;

  @Column({ type: "varchar", length: 128 })
  nameRaw: string;

  @Column({ type: "double precision" })
  value: number;

  @Column({ type: "varchar", length: 32, nullable: true })
  unit: string | null;

  @Column({ type: "double precision", nullable: true })
  refMin: number | null;

  @Column({ type: "double precision", nullable: true })
  refMax: number | null;

  @Column({ type: "varchar", length: 8, nullable: true })
  flag: "high" | "low" | null;
}
