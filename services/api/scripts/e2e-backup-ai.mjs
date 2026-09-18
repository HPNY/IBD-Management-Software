/**
 * 建议下一步验证：备份口令链路（服务端密文）+ AI 降级说明
 * 用法: node scripts/e2e-backup-ai.mjs
 */
const base = process.env.IBD_API_BASE ?? "http://127.0.0.1:3000";

async function req(method, path, { body, token } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      ...(body ? { "content-type": "application/json" } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return text ? JSON.parse(text) : {};
}

const appUserId = `backup-e2e-${Date.now()}`;
const steps = [];

const health = await req("GET", "/health");
steps.push({ step: "health", db: health.db });

// 1 sync-session
const session = await req("POST", "/api/v1/auth/sync-session", {
  body: { appUserId },
});
steps.push({ step: "sync-session", scope: session.scope });

// 2 put ciphertext (含 mac)
const put = await req("POST", "/api/v1/sync/ciphertext", {
  token: session.accessToken,
  body: {
    appUserId,
    dataType: "full",
    cipher: Buffer.from(JSON.stringify({ format: "ibders.backup.v1" })).toString("base64"),
    nonce: Buffer.from("nonce1234567890").toString("base64"),
    mac: Buffer.from("macmacmacmac").toString("base64"),
    clientUpdatedAt: new Date().toISOString(),
    version: Date.now(),
  },
});
steps.push({ step: "put", id: put.id });

// 3 list
const list = await req(
  "GET",
  `/api/v1/sync/ciphertexts?appUserId=${encodeURIComponent(appUserId)}`,
  { token: session.accessToken },
);
if (!list.length) throw new Error("ciphertext missing");
if (!list[0].mac) throw new Error("mac missing");
steps.push({ step: "list", count: list.length, hasMac: !!list[0].mac });

// 4 wipe（删云）
const wipe = await req(
  "DELETE",
  `/api/v1/sync/ciphertexts?appUserId=${encodeURIComponent(appUserId)}`,
  { token: session.accessToken },
);
if (wipe.deleted < 1) throw new Error("wipe failed");
steps.push({ step: "wipe", deleted: wipe.deleted });

// 5 AI：parse-session 可用；worker 无 LLM 时 Skill 仍工作
const ps = await req("POST", "/api/v1/auth/parse-session", {
  body: { appUserId },
});
steps.push({ step: "parse-session", scope: ps.scope });

// 6 Skill 路径解析（不依赖 LLM）
const text = [
  "示例三甲医院A 血常规",
  "采集日期: 2026/04/01",
  "白细胞计数 6.0",
  "血红蛋白 140",
].join("\n");
const presign = await req("POST", "/api/v1/files/presign", {
  token: ps.accessToken,
  body: { filename: "backup-ai.txt", contentType: "text/plain" },
});
const putFile = await fetch(presign.uploadUrl, {
  method: "PUT",
  headers: presign.headers ?? {},
  body: text,
});
if (!putFile.ok) throw new Error(`upload ${putFile.status}`);
const job = await req("POST", "/api/v1/parse/jobs", {
  token: ps.accessToken,
  body: {
    objectKey: presign.objectKey,
    hospitalHint: "示例三甲医院A",
    reportType: "血常规",
  },
});
let st = job;
for (let i = 0; i < 20; i++) {
  st = await req("GET", `/api/v1/parse/jobs/${job.id}`, { token: ps.accessToken });
  if (st.status === "done" || st.status === "failed") break;
  await new Promise((r) => setTimeout(r, 500));
}
if (st.status !== "done" || (st.items ?? []).length < 1) {
  throw new Error(`skill parse failed: ${JSON.stringify(st)}`);
}
steps.push({
  step: "skill_parse",
  status: st.status,
  items: (st.items ?? []).map((i) => `${i.name}=${i.value}`),
});

console.log(JSON.stringify({ ok: true, appUserId, steps }, null, 2));
