/**
 * BullMQ 契约冒烟：不依赖 Postgres。
 * 1) 启动 Redis
 * 2) node 本脚本入队 parsePdf
 * 3) 需另开 parse-worker 消费
 *
 * 用法: REDIS_URL=redis://127.0.0.1:6379 node scripts/queue-smoke.mjs
 */
import { Queue, QueueEvents } from "bullmq";
import { setTimeout as sleep } from "node:timers/promises";

const url = process.env.REDIS_URL ?? "redis://127.0.0.1:6379";
const queueName = process.env.PARSE_QUEUE ?? "parse";
const jobId = `smoke_${Date.now()}`;

const queue = new Queue(queueName, { connection: { url } });
const events = new QueueEvents(queueName, { connection: { url } });

await events.waitUntilReady();

const sampleText = [
  "示例三甲医院A 血常规报告",
  "采集日期: 2026/01/15",
  "白细胞计数 6.2",
  "血红蛋白 145",
].join("\n");

await queue.add(
  "parsePdf",
  {
    jobId,
    patientId: "smoke",
    objectKey: "inline://sample",
    hospitalHint: "示例三甲医院A",
    reportType: "血常规",
    text: sampleText,
  },
  {
    jobId,
    attempts: 1,
    removeOnComplete: 5,
    removeOnFail: 5,
  },
);

console.log(JSON.stringify({ enqueued: true, jobId, queue: queueName }));

const timeoutMs = Number(process.env.SMOKE_TIMEOUT_MS ?? 20000);
const result = await Promise.race([
  new Promise((resolve) => {
    events.on("completed", ({ jobId: id, returnvalue }) => {
      if (id !== jobId) return;
      resolve(
        typeof returnvalue === "string" ? JSON.parse(returnvalue) : returnvalue,
      );
    });
    events.on("failed", ({ jobId: id, failedReason }) => {
      if (id !== jobId) return;
      resolve({ error: failedReason || "failed" });
    });
  }),
  sleep(timeoutMs).then(() => ({ error: "timeout waiting for worker" })),
]);

console.log(JSON.stringify({ completed: true, result }, null, 2));
await queue.close();
await events.close();
process.exit(result?.error ? 1 : 0);
