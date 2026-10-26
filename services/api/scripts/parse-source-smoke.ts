/**
 * T2 冒烟：LabResult.source 判定纯函数矩阵（skill|ai 如实 + 旧数据兼容回退）。
 * 运行：pnpm --filter @ibd/api smoke:parse-source
 */
import assert from "node:assert";
import {
  normalizeParseEngine,
  resolveLabSource,
} from "../src/modules/parse/parse-source";

// normalizeParseEngine：worker 引擎字符串归一
assert.equal(normalizeParseEngine("skill"), "skill");
assert.equal(normalizeParseEngine("ai"), "ai");
assert.equal(normalizeParseEngine("ai-empty"), "ai");
assert.equal(normalizeParseEngine("SKILL"), "skill");
assert.equal(normalizeParseEngine(null), null);
assert.equal(normalizeParseEngine(""), null);
assert.equal(normalizeParseEngine("unknown-engine"), null);

// resolveLabSource：新任务按引擎如实
assert.equal(resolveLabSource({ engine: "skill", skillVersionId: null }), "skill");
assert.equal(resolveLabSource({ engine: "ai", skillVersionId: null }), "ai");
assert.equal(resolveLabSource({ engine: "ai-empty" }), "ai");

// 旧任务兼容回退（engine 列为空的历史数据）：有 skillVersion 视为 skill，否则 ai
assert.equal(resolveLabSource({ engine: null, skillVersionId: "v1" }), "skill");
assert.equal(resolveLabSource({ engine: null, skillVersionId: null }), "ai");
assert.equal(resolveLabSource({}), "ai");

console.log("PARSE_SOURCE_SMOKE PASS");
