/**
 * P0-1 全栈联调：presign → PUT → parse/jobs → 轮询 → 校验落库。
 * 用法: node scripts/e2e-fullstack.mjs
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";

const base = process.env.IBD_API_BASE ?? "http://127.0.0.1:3000";

async function req(method, path, { body, headers, raw } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      ...(body && !raw ? { "content-type": "application/json" } : {}),
      ...headers,
    },
    body: raw ? body : body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  if (!res.ok) {
    throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  }
  return json;
}

const sample = [
  "示例三甲医院A 血常规报告",
  "采集日期: 2026/03/01",
  "白细胞计数 7.1",
  "血红蛋白 138",
].join("\n");

const steps = [];

// 1 health
const health = await req("GET", "/health");
steps.push({ step: "health", db: health.db, status: health.status });
if (health.db !== "ok") throw new Error("API db not ok");

// 2 labs empty (auto demo patient)
const labsBefore = await req("GET", "/api/v1/labs");
steps.push({ step: "labs_before", count: labsBefore.length });

// 3 presign
const presign = await req("POST", "/api/v1/files/presign", {
  body: {
    filename: "e2e-blood.txt",
    contentType: "text/plain",
    expiresInSec: 900,
  },
});
steps.push({ step: "presign", objectKey: presign.objectKey, driver: presign.driver });

// 4 PUT upload
const putRes = await fetch(presign.uploadUrl, {
  method: "PUT",
  headers: presign.headers ?? {},
  body: Buffer.from(sample, "utf8"),
});
if (!putRes.ok) throw new Error(`upload failed ${putRes.status} ${await putRes.text()}`);
steps.push({ step: "upload", status: putRes.status });

// 5 enqueue parse
const job0 = await req("POST", "/api/v1/parse/jobs", {
  body: {
    objectKey: presign.objectKey,
    hospitalHint: "示例三甲医院A",
    reportType: "血常规",
  },
});
steps.push({ step: "enqueue", id: job0.id, status: job0.status });

// 6 poll
let job = job0;
const deadline = Date.now() + 30000;
while (Date.now() < deadline) {
  job = await req("GET", `/api/v1/parse/jobs/${job0.id}`);
  if (job.status === "done" || job.status === "failed") break;
  await new Promise((r) => setTimeout(r, 1000));
}
steps.push({
  step: "poll",
  status: job.status,
  itemCount: (job.items ?? []).length,
  error: job.error ?? null,
});
if (job.status !== "done") {
  console.log(JSON.stringify({ ok: false, steps }, null, 2));
  process.exit(1);
}

// 7 write lab from parsed items (manual confirm step that app would do)
const items = (job.items ?? []).map((i) => ({
  nameNorm: i.name,
  nameRaw: i.name_raw ?? i.name,
  value: i.value,
  unit: i.unit,
  refMin: i.ref_min,
  refMax: i.ref_max,
  flag: i.flag,
}));
const lab = await req("POST", "/api/v1/labs", {
  body: {
    date: "2026-03-01",
    hospital: "示例三甲医院A",
    items,
    source: "skill",
    deviceId: "e2e-device",
  },
});
steps.push({ step: "lab_save", id: lab.id, items: lab.items?.length });

// 8 reload labs
const labsAfter = await req("GET", "/api/v1/labs");
const found = labsAfter.find((l) => l.id === lab.id);
steps.push({
  step: "labs_after",
  count: labsAfter.length,
  foundItems: found?.items?.map((i) => `${i.nameNorm}=${i.value}`),
});

if (!found || found.items?.length !== 2) {
  console.log(JSON.stringify({ ok: false, steps }, null, 2));
  process.exit(1);
}

console.log(JSON.stringify({ ok: true, steps }, null, 2));
