/**
 * C1 回归：`GET /medications/timeline` 不得跨租户返回他人副作用事件。
 *
 * 运行（需 API + DB）：node services/api/scripts/e2e-authz.mjs
 * CI：scripts/ci-fullstack.sh 在 fullstack E2E 阶段调用。
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
  return { status: res.status, json };
}

async function login(prefix) {
  const phone = `${prefix}${String(Date.now()).slice(-8)}`;
  const res = await req("POST", "/api/v1/auth/login", {
    body: { phone, code: DEV_CODE, deviceId: `authz-${prefix}` },
  });
  if (res.status >= 300) {
    throw new Error(`login failed ${res.status} ${JSON.stringify(res.json)}`);
  }
  return { phone, token: res.json.accessToken };
}

const steps = [];
const userA = await login("136");
const userB = await login("135");
steps.push({ step: "login", a: userA.phone, b: userB.phone });

// A 创建用药 + 副作用
const med = await req("POST", "/api/v1/medications", {
  token: userA.token,
  body: {
    drugName: "乌帕替尼",
    dosage: "15mg",
    frequency: "每日一次",
    route: "oral",
    startDate: "2026-01-01",
    status: "active",
  },
});
if (med.status >= 300) throw new Error(`create med ${med.status}`);
const ae = await req("POST", `/api/v1/medications/${med.json.id}/adverse-events`, {
  token: userA.token,
  body: { title: "C1-私有副作用", severity: "moderate", occurredAt: "2026-02-01" },
});
if (ae.status >= 300) throw new Error(`create ae ${ae.status}`);
steps.push({ step: "seed", medicationId: med.json.id, eventId: ae.json.id });

// A 自己可见
const timelineA = await req("GET", "/api/v1/medications/timeline", {
  token: userA.token,
});
const aIds = (timelineA.json.adverseEvents ?? []).map((e) => e.id);
if (!aIds.includes(ae.json.id)) {
  throw new Error("A cannot see own adverse event");
}
steps.push({ step: "owner_visible", events: aIds.length });

// B 不得看到 A 的事件
const timelineB = await req("GET", "/api/v1/medications/timeline", {
  token: userB.token,
});
const bEvents = timelineB.json.adverseEvents ?? [];
const leaked = bEvents.filter((e) => e.id === ae.json.id || e.title === "C1-私有副作用");
steps.push({ step: "tenant_isolated", bEvents: bEvents.length });
if (leaked.length > 0) {
  throw new Error(`C1 regression: leaked ${leaked.length} adverse event(s)`);
}

// 直接读 A 的用药也应 404
const direct = await req("GET", `/api/v1/medications/${med.json.id}`, {
  token: userB.token,
});
steps.push({ step: "direct_read", status: direct.status });
if (direct.status !== 404) {
  throw new Error(`expected 404 for cross-tenant medication, got ${direct.status}`);
}

console.log(JSON.stringify({ ok: true, steps }, null, 2));
