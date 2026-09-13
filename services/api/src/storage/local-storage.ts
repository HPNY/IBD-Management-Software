import { randomUUID } from "node:crypto";
import { createHmac, timingSafeEqual } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, normalize, resolve, sep } from "node:path";

export interface PresignRequest {
  filename: string;
  contentType?: string;
  patientId?: string;
  expiresInSec?: number;
}

export interface PresignResult {
  objectKey: string;
  uploadUrl: string;
  method: "PUT";
  headers: Record<string, string>;
  expiresAt: string;
  driver: "local" | "s3";
}

export interface StorageObject {
  body: Buffer;
  contentType?: string;
  size: number;
}

function sanitizeFilename(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 120) || "file.bin";
}

/** 本地盘直传：objectKey + HMAC 签名，客户端 PUT 到 API。 */
export class LocalObjectStorage {
  readonly driver = "local" as const;

  constructor(
    private readonly rootDir: string,
    private readonly secret: string,
    private readonly publicBaseUrl: string,
  ) {
    if (!existsSync(rootDir)) mkdirSync(rootDir, { recursive: true });
  }

  private sign(objectKey: string, expiresAtMs: number): string {
    return createHmac("sha256", this.secret)
      .update(`${objectKey}\n${expiresAtMs}`)
      .digest("hex");
  }

  verifySignature(objectKey: string, expiresAt: number, sig: string): boolean {
    if (Date.now() > expiresAt) return false;
    const expected = this.sign(objectKey, expiresAt);
    if (expected.length !== sig.length) return false;
    return timingSafeEqual(Buffer.from(expected), Buffer.from(sig));
  }

  presign(req: PresignRequest): PresignResult {
    const expiresInSec = Math.min(req.expiresInSec ?? 900, 3600);
    const expiresAtMs = Date.now() + expiresInSec * 1000;
    const objectKey = [
      "uploads",
      new Date().toISOString().slice(0, 10),
      randomUUID(),
      sanitizeFilename(req.filename),
    ].join("/");
    const sig = this.sign(objectKey, expiresAtMs);
    const expiresAt = new Date(expiresAtMs).toISOString();
    const uploadUrl =
      `${this.publicBaseUrl}/api/v1/files/upload` +
      `?objectKey=${encodeURIComponent(objectKey)}&expires=${expiresAtMs}&sig=${sig}`;
    return {
      objectKey,
      uploadUrl,
      method: "PUT",
      headers: {
        "content-type": req.contentType || "application/octet-stream",
      },
      expiresAt,
      driver: this.driver,
    };
  }

  private resolveSafe(objectKey: string): string {
    const full = resolve(this.rootDir, normalize(objectKey).replace(/^(\.\.(\/|\\|$))+/, ""));
    const root = resolve(this.rootDir);
    if (!full.startsWith(root + sep) && full !== root) {
      throw new Error("invalid objectKey");
    }
    return full;
  }

  put(objectKey: string, body: Buffer, contentType?: string): void {
    const full = this.resolveSafe(objectKey);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, body);
    if (contentType) {
      writeFileSync(`${full}.meta.json`, JSON.stringify({ contentType }));
    }
  }

  get(objectKey: string): StorageObject {
    const full = this.resolveSafe(objectKey);
    const body = readFileSync(full);
    let contentType: string | undefined;
    if (existsSync(`${full}.meta.json`)) {
      try {
        contentType = JSON.parse(readFileSync(`${full}.meta.json`, "utf8")).contentType;
      } catch {
        /* ignore */
      }
    }
    return { body, contentType, size: body.length };
  }

  exists(objectKey: string): boolean {
    return existsSync(this.resolveSafe(objectKey));
  }
}
