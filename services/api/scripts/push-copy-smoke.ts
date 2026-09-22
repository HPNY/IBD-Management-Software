/**
 * 隐私硬约束 smoke：远程推送 title/body 只允许通用文案，data 只带 kind。
 * 运行: node_modules/.bin/ts-node --transpile-only scripts/push-copy-smoke.ts
 */
import {
  GENERIC_PUSH_COPY,
  normalizePushKind,
} from "../src/modules/push/fcm.service";

const FORBIDDEN = [
  "剂量",
  "mg",
  "ml",
  "阿达木",
  "乌帕",
  "英夫利昔",
  "类克",
  "诊断",
  "克罗恩",
  "溃疡性",
  "检验",
  "CRP",
  "血红蛋白",
  "手术",
  "医院",
  "片",
  "粒",
  "皮下",
  "静脉",
];

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

function main() {
  const kinds = ["medication", "injection", "followup", "system"] as const;
  for (const k of kinds) {
    const copy = GENERIC_PUSH_COPY[k];
    assert(!!copy, `missing copy for ${k}`);
    assert(copy.title === "IBDers", `title must be IBDers for ${k}`);
    assert(
      copy.body.startsWith("您有一条") &&
        (copy.body.endsWith("提醒") || copy.body.endsWith("通知")),
      `body must be generic reminder for ${k}, got ${copy.body}`,
    );
    // 允许「用药/注射/复查/系统」类别词；禁止具体药名、剂量、病历
    const blob = `${copy.title}${copy.body}`;
    for (const bad of FORBIDDEN) {
      assert(!blob.includes(bad), `copy for ${k} leaks '${bad}': ${blob}`);
    }
  }

  // normalize 只回落到 system，不接受任意 kind
  assert(normalizePushKind("evil") === "system", "evil kind → system");
  assert(normalizePushKind(undefined) === "system", "undefined kind → system");
  assert(normalizePushKind("medication") === "medication", "medication ok");

  console.log(JSON.stringify({ ok: true, kinds: kinds.length }, null, 2));
}

try {
  main();
} catch (err) {
  console.error(err);
  process.exit(1);
}
