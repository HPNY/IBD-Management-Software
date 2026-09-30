/**
 * M3.4 权限冒烟：scopeAllows + 伪匿名/脱敏约定。
 * 运行：pnpm --filter @ibd/api exec ts-node --transpile-only scripts/doctor-scope-smoke.ts
 */
import assert from "node:assert";
import { scopeAllows } from "../src/modules/doctor/doctor-data.module";

function run() {
  assert.equal(scopeAllows(["labs", "summary"], "labs"), true);
  assert.equal(scopeAllows(["labs"], "symptoms"), false);
  assert.equal(scopeAllows(["labs"], undefined), true);
  console.log("doctor-scope-smoke PASS");
}

run();
