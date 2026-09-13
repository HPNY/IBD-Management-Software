/**
 * P0 全栈联调：登录 JWT → presign → PUT → parse/jobs → 轮询 → 写入 labs。
 * 用法: node scripts/e2e-fullstack.mjs
 */
const base = process.env.IBD_API_BASE ?? "http://127.0.0.1:3000";
const DEV_CODE = process.env.DEV_SMS_CODE ?? "123456";

async function req(method, path, { body, headers, token } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      ...(body ? { "content-type": "application/json" } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
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
const phone = `138${String(Date.now()).slice(-8)}`;

// 1 health (public)
const health = await req("GET", "/health");
steps.push({ step: "health", db: health.db, status: health.status });
if (health.db !== "ok") throw new Error("API db not ok");

// 2 login (public)
const tokens = await req("POST", "/api/v1/auth/login", {
  body: { phone, code: DEV_CODE, deviceId: "e2e-device" },
});
steps.push({
  step: "login",
  userId: tokens.user.id,
  hasAccess: Boolean(tokens.accessToken),
  hasRefresh: Boolean(tokens.refreshToken),
});
const access = tokens.accessToken;

// 3 unauthenticated labs should fail
const unauth = await fetch(`${base}/api/v1/labs`);
steps.push({ step: "labs_unauth", status: unauth.status });
if (unauth.status !== 401) throw new Error("expected 401 without token");

// 4 me
const me = await req("GET", "/api/v1/auth/me", { token: access });
steps.push({ step: "me", phone: me.phone });

// 5 refresh rotation
const rotated = await req("POST", "/api/v1/auth/refresh", {
  body: { refreshToken: tokens.refreshToken },
});
steps.push({ step: "refresh", hasNewAccess: Boolean(rotated.accessToken) });

// 6 labs before
const labsBefore = await req("GET", "/api/v1/labs", { token: access });
steps.push({ step: "labs_before", count: labsBefore.length });

// 7 presign
const presign = await req("POST", "/api/v1/files/presign", {
  token: access,
  body: {
    filename: "e2e-blood.txt",
    contentType: "text/plain",
    expiresInSec: 900,
  },
});
steps.push({ step: "presign", objectKey: presign.objectKey, driver: presign.driver });

// 8 PUT upload (public + HMAC)
const putRes = await fetch(presign.uploadUrl, {
  method: "PUT",
  headers: presign.headers ?? {},
  body: Buffer.from(sample, "utf8"),
});
if (!putRes.ok) throw new Error(`upload failed ${putRes.status} ${await putRes.text()}`);
steps.push({ step: "upload", status: putRes.status });

// 9 enqueue parse
const job0 = await req("POST", "/api/v1/parse/jobs", {
  token: access,
  body: {
    objectKey: presign.objectKey,
    hospitalHint: "示例三甲医院A",
    reportType: "血常规",
  },
});
steps.push({ step: "enqueue", id: job0.id, status: job0.status });

// 10 poll
let job = job0;
const deadline = Date.now() + 30000;
while (Date.now() < deadline) {
  job = await req("GET", `/api/v1/parse/jobs/${job0.id}`, { token: access });
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

// 11 write lab
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
  token: access,
  body: {
    date: "2026-03-01",
    hospital: "示例三甲医院A",
    items,
    source: "skill",
    deviceId: "e2e-device",
  },
});
steps.push({ step: "lab_save", id: lab.id, items: lab.items?.length });

const labsAfter = await req("GET", "/api/v1/labs", { token: access });
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
