import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("refresh_tokens")
@Index(["userId", "tokenHash"], { unique: true })
export class RefreshTokenEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: "CASCADE" })
  user: UserEntity;

  @Column({ type: "varchar", length: 128 })
  tokenHash: string;

  @Column({ type: "varchar", length: 128, nullable: true })
  deviceId: string | null;

  @Column({ type: "timestamptz" })
  expiresAt: Date;

  @Column({ type: "timestamptz", nullable: true })
  revokedAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;
}
