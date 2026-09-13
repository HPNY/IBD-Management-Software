/**
 * 用药产品面 E2E：创建 → 副作用 → 调剂量 → 换药 → timeline。
 * 用法: node scripts/e2e-medication.mjs
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
const phone = `137${String(Date.now()).slice(-8)}`;
const tokens = await req("POST", "/api/v1/auth/login", {
  body: { phone, code: DEV_CODE, deviceId: "med-e2e" },
});
const access = tokens.accessToken;
steps.push({ step: "login", userId: tokens.user.id });

const med1 = await req("POST", "/api/v1/medications", {
  token: access,
  body: {
    drugName: "乌帕替尼",
    brandName: "Rinvoq",
    category: "JAK抑制剂",
    dosage: "15mg",
    frequency: "每日一次",
    route: "oral",
    startDate: "2025-06-01",
    reason: "克罗恩病维持治疗",
    status: "active",
  },
});
steps.push({ step: "create", id: med1.id, drug: med1.drugName });

const ae = await req("POST", `/api/v1/medications/${med1.id}/adverse-events`, {
  token: access,
  body: {
    title: "带状疱疹",
    severity: "moderate",
    occurredAt: "2025-09-01",
  },
});
steps.push({ step: "adverse", title: ae.title, severity: ae.severity });

const adj = await req("POST", `/api/v1/medications/${med1.id}/adjust`, {
  token: access,
  body: {
    dosage: "30mg",
    reason: "应答不佳加量",
    effectiveDate: "2025-10-01",
  },
});
steps.push({
  step: "adjust",
  prevStatus: adj.previous.status,
  nextDosage: adj.current.dosage,
});
if (adj.previous.status !== "stopped" || adj.current.dosage !== "30mg") {
  throw new Error("adjust failed");
}

const sw = await req("POST", "/api/v1/medications/switch", {
  token: access,
  body: {
    fromId: adj.current.id,
    stopReason: "副作用/换生物制剂",
    stopDate: "2025-12-01",
    next: {
      drugName: "利生奇珠单抗",
      brandName: "喜开悦",
      category: "IL-23抑制剂",
      dosage: "180mg",
      frequency: "每8周",
      route: "sc",
      startDate: "2025-12-15",
    },
  },
});
steps.push({
  step: "switch",
  prev: sw.previous.drugName,
  next: sw.current.drugName,
  nextStatus: sw.current.status,
});

const current = await req("GET", "/api/v1/medications/current", {
  token: access,
});
steps.push({
  step: "current",
  drugs: current.map((m) => `${m.drugName}(${m.status})`),
});
if (!current.some((m) => m.drugName === "利生奇珠单抗" && m.status === "active")) {
  throw new Error("current should include new drug");
}

const tl = await req("GET", "/api/v1/medications/timeline", { token: access });
steps.push({
  step: "timeline",
  chain: tl.chainText,
  medCount: tl.medications.length,
  aeCount: tl.adverseEvents.length,
});
if (tl.medications.length < 3) throw new Error("expected switch chain >=3");
if (!tl.adverseEvents.length) throw new Error("expected adverse events");

console.log(JSON.stringify({ ok: true, steps }, null, 2));
