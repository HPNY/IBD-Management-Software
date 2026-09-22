import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

/**
 * 设备推送令牌：只绑定客户端生成的 appUserId（app_user_uuid），
 * 不强制登录、不含病历。可随时按 token 或按 appUserId 注销。
 */
@Entity("device_tokens")
@Index(["token"], { unique: true })
export class DeviceTokenEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "varchar", length: 64 })
  appUserId: string;

  /** FCM/厂商推送 token；本地 dry-run 可为 local: 占位串 */
  @Column({ type: "varchar", length: 512 })
  token: string;

  /** android | ios | web | local */
  @Column({ type: "varchar", length: 32, default: "unknown" })
  platform: string;

  @Column({ type: "timestamptz", nullable: true })
  lastSeenAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
