import { Injectable } from "@nestjs/common";

@Injectable()
export class AuthService {
  /** MVP 骨架：占位。后续接手机号/微信 OAuth + Refresh 旋转。 */
  health() {
    return { module: "auth", ready: false, next: "phone+wechat oauth" };
  }
}
