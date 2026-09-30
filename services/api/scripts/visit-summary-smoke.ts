/**
 * M3.2 VisitSummary 组装冒烟。
 * 运行：pnpm --filter @ibd/api exec ts-node --transpile-only scripts/visit-summary-smoke.ts
 */
import assert from "node:assert";
import { buildVisitSummaryText } from "../src/modules/doctor/visit-summary";

function run() {
  const text = buildVisitSummaryText({
    meds: [{ drugName: "乌帕替尼", dosage: "15mg", frequency: "qd" }],
    labs: [
      {
        date: "2026-09-01",
        items: [
          { nameNorm: "超敏C反应蛋白", value: 5, unit: "mg/L" },
          { nameNorm: "血红蛋白", value: 120, unit: "g/L" },
        ],
      },
    ],
    injections: [{ drug: "阿达木单抗", plannedDate: "2026-10-01", dose: "40mg" }],
    symptoms: [
      {
        date: "2026-09-10",
        painLevel: 3,
        diarrheaCount: 2,
        bowelCount: 3,
        stoolType: 5,
        bloodyStool: "trace",
        urgency: 1,
        mucus: 0,
      },
    ],
    ibdType: "crohns",
    now: new Date("2026-09-15T12:00:00Z"),
  });
  assert.ok(text.includes("【当前用药】"));
  assert.ok(text.includes("乌帕替尼"));
  assert.ok(text.includes("【最近检验（2026-09-01）】"));
  assert.ok(text.includes("超敏C反应蛋白=5mg/L"));
  assert.ok(text.includes("【近期注射】"));
  assert.ok(text.includes("阿达木单抗"));
  assert.ok(text.includes("【症状】"));
  assert.ok(text.includes("便血 擦拭有"));
  assert.ok(text.includes("紧迫"));
  assert.ok(text.includes("诊断类型：crohns"));
  console.log("visit-summary-smoke PASS");
}

run();
