export interface JwtUser {
  userId: string;
  phone: string | null;
  deviceId?: string;
  /** parse_session：仅允许解析相关接口；sync_ciphertext：仅密文同步 */
  scope?: "full" | "parse_session" | "sync_ciphertext";
  appUserId?: string;
}
