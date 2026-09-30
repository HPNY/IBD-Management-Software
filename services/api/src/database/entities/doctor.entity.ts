import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

export type DoctorReviewStatus = "pending" | "approved" | "rejected";

/** M1.1：医生账号（执业信息人工审核占位）。 */
@Entity("doctors")
export class DoctorEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "varchar", length: 128 })
  name: string;

  @Column({ type: "varchar", length: 128, unique: true })
  email: string;

  @Column({ type: "varchar", length: 256 })
  passwordHash: string;

  @Column({ type: "varchar", length: 128, nullable: true })
  hospital: string | null;

  @Column({ type: "varchar", length: 64, nullable: true })
  licenseNo: string | null;

  @Column({
    type: "varchar",
    length: 16,
    default: "pending",
  })
  reviewStatus: DoctorReviewStatus;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

export type GrantScopeKey = "labs" | "symptoms" | "alerts" | "summary";

/** M2.3：患者扫码授权 Grant（可收回、可过期）。 */
@Entity("doctor_grants")
export class DoctorGrantEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  doctorId: string;

  @Column({ type: "uuid" })
  patientId: string;

  @Column({ type: "jsonb" })
  scope: GrantScopeKey[];

  @Column({ type: "varchar", length: 64, unique: true })
  code: string;

  @Column({ type: "timestamptz" })
  expiresAt: Date;

  @Column({ type: "timestamptz", nullable: true })
  revokedAt: Date | null;

  /** M2.4：范围内 DEK/子密钥经医生公钥再包裹（服务端不落明文 DEK） */
  @Column({ type: "text", nullable: true })
  wrappedDek: string | null;

  @Column({ type: "boolean", default: false })
  confirmed: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
