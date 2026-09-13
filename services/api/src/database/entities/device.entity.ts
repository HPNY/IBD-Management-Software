import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("devices")
@Index(["userId", "deviceId"], { unique: true })
export class DeviceEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  userId: string;

  @ManyToOne(() => UserEntity, (u) => u.devices, { onDelete: "CASCADE" })
  user: UserEntity;

  @Column({ type: "varchar", length: 128 })
  deviceId: string;

  @Column({ type: "varchar", length: 64, default: "unknown" })
  platform: string;

  @Column({ type: "timestamptz", nullable: true })
  lastSeenAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;
}
