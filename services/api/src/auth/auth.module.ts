import { Module } from "@nestjs/common";
import { APP_GUARD } from "@nestjs/core";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { JwtModule } from "@nestjs/jwt";
import { TypeOrmModule } from "@nestjs/typeorm";
import {
  DevicePubKeyEntity,
  RefreshTokenEntity,
  UserEntity,
} from "../database/entities";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { JwtAuthGuard } from "./jwt-auth.guard";

@Module({
  imports: [
    // T0.6：AuthService 注入 DevicePubKeyEntityRepository（R0.13 DPoP），
    // 必须在此注册，否则 Nest 启动期 DI 解析失败（E2E 起不来）。
    TypeOrmModule.forFeature([
      UserEntity,
      RefreshTokenEntity,
      DevicePubKeyEntity,
    ]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET") ?? "dev-jwt-secret-change-me",
        signOptions: { expiresIn: config.get("JWT_ACCESS_TTL") ?? "15m" },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtAuthGuard,
    { provide: APP_GUARD, useClass: JwtAuthGuard },
  ],
  exports: [JwtModule, AuthService],
})
export class AuthModule {}
