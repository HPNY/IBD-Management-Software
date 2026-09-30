import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from "typeorm";

/** D2：匿名药物评价（无病历字段）。 */
@Entity("drug_review_submissions")
@Index(["drugName", "raterHash"], { unique: true })
export class DrugReviewSubmissionEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "varchar", length: 128 })
  drugName: string;

  @Column({ type: "varchar", length: 8, default: "unknown" })
  ibdType: string;

  @Column({ type: "int" })
  efficacy: number;

  @Column({ type: "int" })
  seSideEffect: number;

  @Column({ type: "jsonb", nullable: true })
  sideEffectTypes: string[] | null;

  @Column({ type: "boolean", default: true })
  stillUsing: boolean;

  @Column({ type: "varchar", length: 500, nullable: true })
  comment: string | null;

  @Column({ type: "varchar", length: 64 })
  raterHash: string;

  @CreateDateColumn()
  createdAt: Date;
}
