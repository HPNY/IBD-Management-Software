/**
 * 直传 + BullMQ + worker 端到端冒烟（不依赖 Postgres/Nest 启动）。
 * 需本机 Redis 与 parse-worker。
 * 用法: REDIS_URL=redis://127.0.0.1:6380 node scripts/storage-queue-smoke.mjs
 */
import { Queue, QueueEvents } from "bullmq";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";

// 复用编译后的 local-storage 太麻烦，这里内联最小 put
import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { randomUUID } from "node:crypto";

const __dirname = dirname(fileURLToPath(import.meta.url));
const url = process.env.REDIS_URL ?? "redis://127.0.0.1:6379";
const queueName = process.env.PARSE_QUEUE ?? "parse";
const jobId = `store_${Date.now()}`;

const localDir = process.env.STORAGE_LOCAL_DIR ?? mkdtempSync(join(tmpdir(), "ibd-up-"));
if (!existsSync(localDir)) mkdirSync(localDir, { recursive: true });

const objectKey = `uploads/smoke/${randomUUID()}/report.txt`;
const fullPath = join(localDir, objectKey);
mkdirSync(dirname(fullPath), { recursive: true });
const sampleText = [
  "示例三甲医院A 血常规报告",
  "采集日期: 2026/01/20",
  "白细胞计数 5.5",
  "血红蛋白 132",
].join("\n");
writeFileSync(fullPath, sampleText, "utf8");

const queue = new Queue(queueName, { connection: { url } });
const events = new QueueEvents(queueName, { connection: { url } });
await events.waitUntilReady();

await queue.add(
  "parsePdf",
  {
    jobId,
    patientId: "smoke",
    objectKey,
    hospitalHint: "示例三甲医院A",
    reportType: "血常规",
    text: null,
    storage: { driver: "local", localDir },
  },
  { jobId, attempts: 1, removeOnComplete: 5, removeOnFail: 5 },
);

console.log(JSON.stringify({ enqueued: true, jobId, objectKey, localDir }));

const result = await Promise.race([
  new Promise((resolve) => {
    events.on("completed", ({ jobId: id, returnvalue }) => {
      if (id !== jobId) return;
      resolve(typeof returnvalue === "string" ? JSON.parse(returnvalue) : returnvalue);
    });
    events.on("failed", ({ jobId: id, failedReason }) => {
      if (id !== jobId) return;
      resolve({ error: failedReason || "failed" });
    });
  }),
  sleep(Number(process.env.SMOKE_TIMEOUT_MS ?? 20000)).then(() => ({
    error: "timeout waiting for worker",
  })),
]);

console.log(JSON.stringify({ result }, null, 2));
await queue.close();
await events.close();
process.exit(result?.error ? 1 : 0);
