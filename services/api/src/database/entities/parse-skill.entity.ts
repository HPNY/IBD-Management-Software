import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { UserEntity } from "./user.entity";

@Entity("parse_skills")
@Index(["hospital", "reportType"], { unique: true })
export class ParseSkillEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "varchar", length: 128 })
  hospital: string;

  @Column({ type: "varchar", length: 64 })
  reportType: string;

  @Column({ type: "varchar", length: 64, nullable: true })
  currentVersion: string | null;

  @Column({ type: "uuid", nullable: true })
  createdById: string | null;

  @ManyToOne(() => UserEntity, { onDelete: "SET NULL" })
  createdBy: UserEntity | null;

  @OneToMany(() => ParseSkillVersionEntity, (v) => v.skill)
  versions: ParseSkillVersionEntity[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

@Entity("parse_skill_versions")
@Index(["skillId", "version"], { unique: true })
export class ParseSkillVersionEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  skillId: string;

  @ManyToOne(() => ParseSkillEntity, (s) => s.versions, { onDelete: "CASCADE" })
  skill: ParseSkillEntity;

  @Column({ type: "varchar", length: 64 })
  version: string;

  /** 完整 Skill JSON（date_extraction / items / special_rules） */
  @Column({ type: "jsonb" })
  content: Record<string, unknown>;

  @Column({ type: "varchar", length: 32, default: "ai_generated" })
  source: "ai_generated" | "user_confirmed" | "manual" | "community";

  @Column({ type: "double precision", nullable: true })
  accuracy: number | null;

  @Column({ type: "int", default: 0 })
  usageCount: number;

  @Column({ type: "boolean", default: false })
  sharedToCommunity: boolean;

  @Column({ type: "uuid", nullable: true })
  createdById: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
