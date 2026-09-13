export interface JwtUser {
  userId: string;
  phone: string | null;
  deviceId?: string;
}
