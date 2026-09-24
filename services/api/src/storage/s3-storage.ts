import { randomUUID } from "node:crypto";
import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import type {
  PresignRequest,
  PresignResult,
  StorageObject,
} from "./local-storage";

function sanitizeFilename(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 120) || "file.bin";
}

/** S3 / MinIO / OSS(S3兼容) 预签名直传。 */
export class S3ObjectStorage {
  readonly driver = "s3" as const;

  constructor(
    private readonly client: S3Client,
    private readonly bucket: string,
    private readonly keyPrefix = "ibd",
  ) {}

  async presign(req: PresignRequest): Promise<PresignResult> {
    const expiresInSec = Math.min(req.expiresInSec ?? 900, 3600);
    const objectKey = [
      this.keyPrefix,
      "uploads",
      new Date().toISOString().slice(0, 10),
      randomUUID(),
      sanitizeFilename(req.filename),
    ].join("/");
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: objectKey,
      ContentType: req.contentType || "application/octet-stream",
    });
    const uploadUrl = await getSignedUrl(this.client, command, {
      expiresIn: expiresInSec,
    });
    return {
      objectKey,
      uploadUrl,
      method: "PUT",
      headers: {
        "content-type": req.contentType || "application/octet-stream",
      },
      expiresAt: new Date(Date.now() + expiresInSec * 1000).toISOString(),
      driver: this.driver,
    };
  }

  async get(objectKey: string): Promise<StorageObject> {
    const res = await this.client.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: objectKey }),
    );
    const bytes = await res.Body?.transformToByteArray();
    const body = Buffer.from(bytes ?? []);
    return {
      body,
      contentType: res.ContentType,
      size: body.length,
    };
  }

  /** 删除对象；不存在视为成功（幂等）。 */
  async delete(objectKey: string): Promise<void> {
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: objectKey }),
    );
  }
}
