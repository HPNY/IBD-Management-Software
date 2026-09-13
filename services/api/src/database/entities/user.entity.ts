import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { DeviceEntity } from "./device.entity";
import { PatientEntity } from "./patient.entity";

@Entity("users")
export class UserEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Index({ unique: true })
  @Column({ type: "varchar", length: 64, nullable: true })
  phone: string | null;

  @Index({ unique: true })
  @Column({ type: "varchar", length: 128, nullable: true })
  wechatOpenId: string | null;

  @Column({ type: "varchar", length: 64, default: "active" })
  status: string;

  @OneToMany(() => DeviceEntity, (d) => d.user)
  devices: DeviceEntity[];

  @OneToMany(() => PatientEntity, (p) => p.user)
  patients: PatientEntity[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
