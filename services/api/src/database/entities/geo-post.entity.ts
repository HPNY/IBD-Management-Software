import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from "typeorm";

/** D3：城市级匿名帖（无精确位置字段）。 */
@Entity("geo_posts")
export class GeoPostEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "varchar", length: 64 })
  city: string;

  @Column({ type: "varchar", length: 64 })
  nickname: string;

  @Column({ type: "varchar", length: 500 })
  content: string;

  @Column({ type: "varchar", length: 64 })
  authorHash: string;

  @CreateDateColumn()
  createdAt: Date;
}
