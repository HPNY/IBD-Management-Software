import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

/** T6.1：社区评分（匿名 appUser 哈希；无病历字段）。 */
@Entity("skill_ratings")
@Index(["skillId", "raterHash"], { unique: true })
export class SkillRatingEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  skillId: string;

  @Column({ type: "uuid", nullable: true })
  versionId: string | null;

  /** 匿名评分者（app_user_uuid 哈希或 uuid），不存真实身份 */
  @Column({ type: "varchar", length: 64 })
  raterHash: string;

  /** 1–5 */
  @Column({ type: "int" })
  score: number;

  @Column({ type: "varchar", length: 500, nullable: true })
  comment: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
