import {
  Column,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from "typeorm";

/**
 * H3（DPoP-lite）：设备 Ed25519 公钥登记。
 * 换短会话时客户端以私钥对 `appUserId|nonce` 签名，服务端验签后登记公钥，
 * 并把公钥指纹（sha256 前 16 字节）写入 JWT；后续请求以 X-PoP 头证明持有私钥。
 * 服务端不存私钥，只存公钥（base64）与指纹，可随时按 appUserId 删除换钥。
 */
@Index(["appUserId"], { unique: true })
@Entity("device_pubkeys")
export class DevicePubKeyEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  /** 客户端生成的 app_user_uuid（非登录账号） */
  @Column({ type: "varchar", length: 64 })
  appUserId: string;

  /** Ed25519 公钥（base64，32 字节） */
  @Column({ type: "text" })
  publicKey: string;

  /** 公钥指纹（sha256 前 16 字节 hex），随 JWT 下发用于 X-PoP 验签 */
  @Column({ type: "varchar", length: 32 })
  pubKeyHash: string;

  /** 首次登记（换会话）时间 */
  @Column({ type: "timestamptz" })
  createdAt: Date;

  /** 最近一次换会话时间（用于淘汰长期不活跃设备） */
  @Column({ type: "timestamptz", nullable: true })
  lastSeenAt: Date | null;
}
