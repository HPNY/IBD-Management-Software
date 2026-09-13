/**
 * 本地 storage 契约冒烟：presign 签名校验 + put/get。
 * 运行: pnpm --filter @ibd/api smoke:storage
 */
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { LocalObjectStorage } from "../src/storage/local-storage";

const root = mkdtempSync(join(tmpdir(), "ibd-storage-"));
const storage = new LocalObjectStorage(root, "smoke-secret", "http://localhost:3000");

const presigned = storage.presign({
  filename: "报告.pdf",
  contentType: "application/pdf",
});

const url = new URL(presigned.uploadUrl);
const objectKey = decodeURIComponent(url.searchParams.get("objectKey")!);
const expires = Number(url.searchParams.get("expires"));
const sig = url.searchParams.get("sig")!;

if (!storage.verifySignature(objectKey, expires, sig)) {
  throw new Error("signature verify failed");
}
if (storage.verifySignature(objectKey, expires, "deadbeef")) {
  throw new Error("bad signature accepted");
}

const pdfMagic = Buffer.from("%PDF-1.4\nsmoke\n");
storage.put(objectKey, pdfMagic, "application/pdf");
const got = storage.get(objectKey);
if (!got.body.equals(pdfMagic)) throw new Error("body mismatch");
if (got.size !== pdfMagic.length) throw new Error("size mismatch");

console.log(
  JSON.stringify(
    {
      ok: true,
      driver: storage.driver,
      objectKey,
      size: got.size,
      uploadUrlSample: presigned.uploadUrl.slice(0, 80) + "...",
    },
    null,
    2,
  ),
);
