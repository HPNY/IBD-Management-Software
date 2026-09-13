import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("patients")
export class PatientEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "uuid" })
  userId: string;

  @ManyToOne(() => UserEntity, (u) => u.patients, { onDelete: "CASCADE" })
  user: UserEntity;

  @Column({ type: "varchar", length: 64 })
  name: string;

  @Column({ type: "varchar", length: 16 })
  sex: "male" | "female" | "other";

  @Column({ type: "date" })
  birthDate: string;

  @Column({ type: "date" })
  diagnosisDate: string;

  @Column({ type: "varchar", length: 16 })
  ibdType: "crohns" | "uc";

  @Column({ type: "varchar", length: 64, nullable: true })
  caseNumber: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
