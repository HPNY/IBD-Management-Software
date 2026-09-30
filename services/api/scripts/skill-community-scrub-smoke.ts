/**
 * T6.1 隐私白名单冒烟：skill-community.scrub
 * 运行：node -r ts-node/register/transpile-only scripts/skill-community-scrub-smoke.ts
 * 或：pnpm --filter @ibd/api exec ts-node --transpile-only scripts/skill-community-scrub-smoke.ts
 */
import assert from "node:assert";
import { scrubSkillContent } from "../src/modules/skill/skill-community.scrub";

function run() {
  const good = {
    hospital: "某三甲医院",
    reportType: "血常规",
    version: "1.0.0",
    dateExtraction: { primary: "采集日期:?\\s*(\\d{4})" },
    items: [
      {
        name: "血红蛋白",
        pattern: "血红蛋白\\s+([\\d.]+)",
        unit: "g/L",
        refRange: [115, 150],
      },
    ],
    source: "user_confirmed",
  };
  const ok = scrubSkillContent(good);
  assert.equal(ok.ok, true, `expected ok, got ${JSON.stringify(ok.errors)}`);
  assert.equal(ok.cleaned?.source, "community");
  assert.equal((ok.cleaned?.items as unknown[]).length, 1);

  // 病历号
  const badId = {
    ...good,
    patientId: "123456",
  };
  assert.equal(scrubSkillContent(badId).ok, false);

  // 值中的身份证
  const badValue = {
    ...good,
    hospital: "张三 110101199001011234",
  };
  assert.equal(scrubSkillContent(badValue).ok, false);

  // items 缺 pattern
  const badItem = {
    ...good,
    items: [{ name: "血红蛋白" }],
  };
  assert.equal(scrubSkillContent(badItem).ok, false);

  // 未知顶层键
  const extra = { ...good, reportText: "原始报告" };
  assert.equal(scrubSkillContent(extra).ok, false);

  console.log("skill-community-scrub-smoke PASS");
}

run();
