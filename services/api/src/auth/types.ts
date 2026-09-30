export interface JwtUser {
  userId: string;
  phone: string | null;
  deviceId?: string;
  /** parse_session：解析；sync_ciphertext：密文同步；push_register：设备令牌；community：Skill 社区 */
  scope?: "full" | "parse_session" | "sync_ciphertext" | "push_register" | "community";
  appUserId?: string;
}
