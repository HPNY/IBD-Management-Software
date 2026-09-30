import assert from "node:assert";
import { createHash } from "node:crypto";

/** 与 geo/drug 使用的伪匿名算法一致：SHA-256 前 16 hex */
function pseudoHash(id: string): string {
  return createHash("sha256").update(id).digest("hex").slice(0, 16);
}

function run() {
  assert.equal(pseudoHash("user-a"), pseudoHash("user-a"));
  assert.notEqual(pseudoHash("user-a"), pseudoHash("user-b"));
  assert.equal(pseudoHash("user-a").length, 16);
  console.log("pseudonym-smoke PASS");
}
run();
