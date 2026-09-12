import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { UserEntity } from "../../database/entities";

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly users: Repository<UserEntity>,
  ) {}

  async health() {
    const count = await this.users.count().catch(() => -1);
    return {
      module: "auth",
      ready: count >= 0,
      userCount: count,
      next: "phone+wechat oauth",
    };
  }

  /** 骨架：固定 demo 用户；生产改为登录流程。 */
  ensureDemoUser(): Promise<UserEntity> {
    return this.users
      .findOne({ where: { phone: "demo" } })
      .then((u) => u ?? this.users.save(this.users.create({ phone: "demo" })));
  }
}
