import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

/**
 * 端到端密文快照：服务端只存 cipher，不读病历明文。
 * appUserId 为客户端生成 UUID（非登录账号）。
 */
@Entity("sync_snapshots")
@Index(["appUserId", "dataType"], { unique: true })
export class SyncSnapshotEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index()
  @Column({ type: "varchar", length: 64 })
  appUserId: string;

  /** labs | medications | injections | symptoms | full */
  @Column({ type: "varchar", length: 32 })
  dataType: string;

  /** base64 ciphertext */
  @Column({ type: "text" })
  cipher: string;

  /** base64 nonce/iv */
  @Column({ type: "text" })
  nonce: string;

  /** 版本号，客户端单调递增 */
  @Column({ type: "bigint", default: "1" })
  version: string;

  @Column({ type: "timestamptz" })
  clientUpdatedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
