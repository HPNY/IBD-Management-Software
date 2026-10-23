import { createHash, createPublicKey, verify, randomBytes } from "node:crypto";

/**
 * H3（DPoP-lite）设备持有证明（Proof-of-Possession）工具。
 *
 * 客户端以 Ed25519 私钥对 `${appUserId}|${nonce}` 签名，服务端用登记的公钥验签。
 * 验签通过才签发短会话，且 JWT 内嵌公钥指纹（popKeyHash）；后续请求以 X-PoP 头
 * 对 `${method}|${path}|${nonce}` 签名，服务端验签，确保 token 被窃取也无法单独使用。
 */

/** Ed25519 公钥（base64）→ 公钥指纹（sha256 前 16 字节 hex，与 entity.pubKeyHash 一致）。 */
export function publicKeyFingerprint(publicKeyB64: string): string {
  return createHash("sha256")
    .update(Buffer.from(publicKeyB64, "base64"))
    .digest("hex")
    .slice(0, 32);
}

/** 校验 Ed25519 公钥（base64）合法性；非法格式返回 false。 */
function isValidPublicKey(publicKeyB64: string): boolean {
  try {
    const raw = Buffer.from(publicKeyB64, "base64");
    // Ed25519 公钥原始长度 32 字节
    if (raw.length !== 32) return false;
    createPublicKey({ key: raw, format: "der", type: "spki" });
    return true;
  } catch {
    return false;
  }
}

/**
 * 验证 Ed25519 签名：data 为被签名字节，signature 为 base64 签名，publicKeyB64 为 base64 公钥。
 * 任一格式非法或验签失败均返回 false（不抛错，避免信息泄露）。
 */
export function verifyEd25519(
  publicKeyB64: string,
  data: string,
  signatureB64: string,
): boolean {
  try {
    if (!isValidPublicKey(publicKeyB64)) return false;
    const raw = Buffer.from(publicKeyB64, "base64");
    const keyObj = createPublicKey({ key: raw, format: "der", type: "spki" });
    const sig = Buffer.from(signatureB64, "base64");
    return verify(null, Buffer.from(data, "utf8"), keyObj, sig);
  } catch {
    return false;
  }
}

/**
 * 换会话时的被签名字节：`${appUserId}|${nonce}`。
 * nonce 由服务端在上一次响应返回（或本次请求自带），防重放。
 */
export function sessionSignPayload(appUserId: string, nonce: string): string {
  return `${appUserId}|${nonce}`;
}

/** 请求级 X-PoP 被签名字节：`${method}|${path}|${nonce}`。 */
export function requestSignPayload(
  method: string,
  path: string,
  nonce: string,
): string {
  return `${method.toUpperCase()}|${path}|${nonce}`;
}

/** 生成一次性 nonce（防重放）。 */
export function newNonce(): string {
  return randomBytes(16).toString("base64url");
}
