/**
 * 注射排期 + 到期提醒 E2E。
 * 用法: node scripts/e2e-injection.mjs
 */
const base = process.env.IBD_API_BASE ?? "http://127.0.0.1:3000";
const DEV_CODE = process.env.DEV_SMS_CODE ?? "123456";

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
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return json;
}

const steps = [];
const phone = `139${String(Date.now()).slice(-8)}`;
const tokens = await req("POST", "/api/v1/auth/login", {
  body: { phone, code: DEV_CODE, deviceId: "inj-e2e" },
});
const access = tokens.accessToken;
steps.push({ step: "login", userId: tokens.user.id });

// 协议列表
const protocols = await req("GET", "/api/v1/injections/protocols", {
  token: access,
});
steps.push({ step: "protocols", keys: protocols.map((p) => p.drugKey) });

// 默认提醒规则 leadDays=3
await req("POST", "/api/v1/reminders", {
  token: access,
  body: { kind: "injection", leadDays: 3, enabled: true },
});

// 以「今天 - 1 天」为 start，保证 W0 已到期
const start = new Date(Date.now() - 1 * 86400000).toISOString().slice(0, 10);
const schedule = await req("POST", "/api/v1/injections/schedule", {
  token: access,
  body: { drugKey: "skyrizi", startDate: start },
});
steps.push({
  step: "schedule",
  drug: schedule.drug,
  count: schedule.count,
  first: schedule.injections[0]?.plannedDate,
  phases: [...new Set(schedule.injections.map((i) => i.phase))],
});
if (schedule.count < 4) throw new Error("schedule too short");

// upcoming
const upcoming = await req("GET", "/api/v1/injections/upcoming?withinDays=14", {
  token: access,
});
steps.push({ step: "upcoming", count: upcoming.length });

// due reminders（含今天/3 天内）
const due = await req("GET", "/api/v1/reminders/due", { token: access });
steps.push({
  step: "due",
  count: due.length,
  sample: due[0]?.message,
});
if (!due.length) throw new Error("expected due injection reminders");

// 完成第一针，晚 5 天 → 后续顺延
const first = upcoming[0] ?? schedule.injections[0];
const late = new Date(
  new Date(`${first.plannedDate}T00:00:00Z`).getTime() + 5 * 86400000,
)
  .toISOString()
  .slice(0, 10);
const done = await req("POST", `/api/v1/injections/${first.id}/complete`, {
  token: access,
  body: { actualDate: late, rescheduleDelay: true },
});
steps.push({
  step: "complete",
  delayDays: done.delayDays,
  shifted: done.shifted,
  actualDate: done.injection.actualDate,
});
if (done.delayDays !== 5) throw new Error(`expected delay 5, got ${done.delayDays}`);
if (done.shifted < 1) throw new Error("expected shift future injections");

const after = await req("GET", "/api/v1/injections", { token: access });
const next = after.find((i) => !i.actualDate);
const originalSecond = schedule.injections[1].plannedDate;
steps.push({
  step: "after_shift",
  nextPlanned: next?.plannedDate,
  originalSecond,
});
if (!next || next.plannedDate <= first.plannedDate) {
  throw new Error("future plan not shifted forward");
}

console.log(JSON.stringify({ ok: true, steps }, null, 2));
