/**
 * C3 回归：worker 输出 → confirm 载荷映射。
 *
 * 运行：node apps/web/scripts/parse-items-smoke.mjs
 * 不依赖浏览器/构建产物：用项目内 TypeScript 转译后动态导入。
 */
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = dirname(fileURLToPath(import.meta.url));
const sourcePath = resolve(here, "../src/lib/parse-items.ts");
const source = readFileSync(sourcePath, "utf8");
const js = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
    isolatedModules: true,
  },
  fileName: sourcePath,
}).outputText;

const mod = await import(
  `data:text/javascript;base64,${Buffer.from(js, "utf8").toString("base64")}`
);
const { toLabItem, toLabItems } = mod;

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

// 1) worker snake_case → confirm camelCase
const workerItem = {
  name: "超敏C反应蛋白",
  name_raw: "hs-CRP",
  value: 8.2,
  unit: "mg/L",
  ref_min: 0,
  ref_max: 5,
  flag: "high",
};
const mapped = toLabItem(workerItem);
assert(mapped, "worker item should map");
assert(mapped.nameNorm === "超敏C反应蛋白", "nameNorm must come from name");
assert(mapped.nameRaw === "hs-CRP", "nameRaw must come from name_raw");
assert(mapped.refMin === 0 && mapped.refMax === 5, "ref range must map");
assert(mapped.flag === "high", "flag must pass through");

// 2) 已是 camelCase 的输入保持兼容
const camel = toLabItem({ nameNorm: "白蛋白", nameRaw: "ALB", value: 45 });
assert(camel?.nameNorm === "白蛋白" && camel.value === 45, "camelCase input");

// 3) 定性值不得写回（value=null / 字符串 / 运算符）
assert(toLabItem({ name: "隐血", value: null }) === null, "null value dropped");
assert(
  toLabItem({ name: "隐血", value: "阴性", value_text: "阴性" }) === null,
  "qualitative value dropped",
);
assert(toLabItem({ name: "粪便钙卫蛋白", value: ">1800" }) === null, "operator value dropped");

// 4) NaN / 缺名不得写回
assert(toLabItem({ name: "CRP", value: Number.NaN }) === null, "NaN dropped");
assert(toLabItem({ value: 1 }) === null, "missing name dropped");

// 5) 批量过滤
const batch = toLabItems([workerItem, { name: "隐血", value: "阴性" }, null]);
assert(batch.length === 1, "batch should keep only numeric item");

console.log(
  JSON.stringify(
    {
      ok: true,
      mapped: mapped.nameNorm,
      batchKept: batch.length,
      checks: 9,
    },
    null,
    2,
  ),
);
