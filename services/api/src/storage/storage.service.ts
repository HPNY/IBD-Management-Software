import { Injectable } from "@nestjs/common";
import { S3Client } from "@aws-sdk/client-s3";
import { LocalObjectStorage, PresignRequest, PresignResult, StorageObject } from "./local-storage";
import { S3ObjectStorage } from "./s3-storage";

export type AnyStorage = LocalObjectStorage | S3ObjectStorage;

@Injectable()
export class StorageService {
  private readonly impl: AnyStorage;

  constructor() {
    const driver = process.env.STORAGE_DRIVER ?? "local";
    if (driver === "s3") {
      const region = process.env.S3_REGION ?? "us-east-1";
      const endpoint = process.env.S3_ENDPOINT; // MinIO / OSS
      this.impl = new S3ObjectStorage(
        new S3Client({
          region,
          endpoint,
          forcePathStyle: process.env.S3_FORCE_PATH_STYLE !== "false",
          credentials:
            process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY
              ? {
                  accessKeyId: process.env.S3_ACCESS_KEY_ID,
                  secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
                }
              : undefined,
        }),
        process.env.S3_BUCKET ?? "ibd-uploads",
        process.env.S3_PREFIX ?? "ibd",
      );
    } else {
      this.impl = new LocalObjectStorage(
        process.env.STORAGE_LOCAL_DIR ?? "var/uploads",
        process.env.STORAGE_SECRET ?? "dev-storage-secret",
        process.env.PUBLIC_BASE_URL ?? "http://localhost:3000",
      );
    }
  }

  get driver() {
    return this.impl.driver;
  }

  presign(req: PresignRequest): PresignResult | Promise<PresignResult> {
    return this.impl.presign(req);
  }

  get(objectKey: string): StorageObject | Promise<StorageObject> {
    return this.impl.get(objectKey);
  }

  putLocal(objectKey: string, body: Buffer, contentType?: string) {
    if (this.impl instanceof LocalObjectStorage) {
      this.impl.put(objectKey, body, contentType);
      return;
    }
    throw new Error("putLocal only available for local driver");
  }

  verifyLocalSignature(objectKey: string, expires: number, sig: string) {
    if (this.impl instanceof LocalObjectStorage) {
      return this.impl.verifySignature(objectKey, expires, sig);
    }
    return false;
  }
}
