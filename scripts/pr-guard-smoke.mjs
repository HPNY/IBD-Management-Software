#!/usr/bin/env node
/**
 * pr-guard 单元冒烟：`pnpm pr:guard:smoke`
 *
 * 为什么需要：2026-11-13 合并分支时，PR #7（`P11: ...`）被守卫判为
 * 「缺少任务号」——因为 TASK_RE 只认 `T/F/G` 三种前缀，而 worklist 里
 * 同时存在 `P`/`U`/`V`/`W`/`M`/`R`/`D` 等前缀。守卫本身没有测试，
 * 这个缺陷在 CI 里表现为「合法 PR 直接红」，只能靠人工读脚本发现。
 *
 * 本脚本以子进程方式调用 pr-guard.mjs，注入伪造的 PR 元数据，
 * 断言正例 exit 0、负例 exit 1。不依赖任何测试框架（仓库无 vitest/jest）。
 */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const guard = join(here, "pr-guard.mjs");

/** 一份能通过描述校验的最小 body（7 条勾选 + 必需章节 + 定级 + 证据） */
const OK_BODY = [
  "## 变更概要",
  "- **变更定级**：C1 轻量",
  "## 影响范围",
  "无",
  "## 证据",
  "```",
  "pnpm lint → 0 error, exit 0",
  "```",
  "## 自查清单",
  ...Array.from({ length: 7 }, (_, i) => `- [x] 第 ${i + 1} 条`),
  "## 回滚方式",
  "git revert <sha>",
].join("\n");

/**
 * 跑一次守卫。
 * @param {{title: string, head: string, body?: string, draft?: string}} c
 * @returns {number} 退出码
 */
function run(c) {
  const r = spawnSync(process.execPath, [guard], {
    env: {
      ...process.env,
      PR_TITLE: c.title,
      PR_HEAD_REF: c.head,
      PR_BODY: c.body ?? OK_BODY,
      PR_NUMBER: "smoke",
      PR_AUTHOR: "smoke",
      PR_IS_DRAFT: c.draft ?? "false",
    },
    encoding: "utf8",
  });
  return r.status ?? -1;
}

const cases = [];

/** @param {string} name @param {string} title @param {string} head */
function pass(name, title, head) {
  cases.push({ name, title, head, want: 0 });
}

/** @param {string} name @param {string} title @param {string} head @param {object} [extra] */
function fail(name, title, head, extra = {}) {
  cases.push({ name, title, head, want: 1, ...extra });
}

// ---- 正例：worklist 实际使用的全部 9 类前缀 + 具名任务号 ----
pass("T 系列（含小数点）", "T8.2: 补 lint 基线", "task/t8-review-mechanism");
pass("T 系列（纯编号）", "T0.3: 工程约束", "task/t0.3-engineering-constraints");
pass("P 系列（阶段号）", "P11: 登记合并收口", "docs/p11-merge-record");
pass("U 系列（UI 评审）", "U7: 分析 Tab 四组分层", "task/u7-analysis-groups");
pass("V 系列（PRD 对齐）", "V13-05: 数据模型对齐", "task/v13-prd-docs");
pass("W 系列（评审 P0）", "W0-03: confirm 前映射", "task/w0-review-p0-fixes");
pass("M 系列（合并收口）", "M4: 暗色残留清零", "chore/m4-dark-leftover");
pass("R 系列（二次验证）", "R0.6: 修复 wx 类型错误", "fix/r06-wx-types");
pass("D 系列（V2 四轨）", "D2: 饮食轨道", "feature/d2-diet");
pass("F 系列（验收）", "F1: P0 验收", "task/f1-acceptance");
pass("G 系列（门禁）", "G2: 证据门禁", "task/g2-gate");
pass("具名任务号", "SWIPER-R1: 真机兼容验证", "fix/swiper-r1-verify");
pass("仅分支名带任务号（小写约定）", "补齐文档", "docs/p11-merge-record");
pass("分支名小写 t 系列", "补齐文档", "task/t8-review-mechanism");

// ---- 负例 ----
fail("标题与分支都无任务号", "修个 bug", "docs/fix-something");
fail("通用英文标题", "update readme", "chore/update");
fail("前缀后无编号", "P: 空编号", "task/p-empty");
fail("编号嵌在单词里", "XP11: 不是任务号", "task/xp11");
pass("小写前缀也算（大小写不敏感）", "p11: 小写同样合法", "task/p11-lower");
fail("任务号后面粘字母", "P11x: 粘连", "task/p11x");

// ---- 描述类负例（任务号合法，描述不合规）----
fail("body 为空", "P11: 空描述", "docs/p11-empty", { body: "" });
fail("缺「回滚方式」章节", "P11: 缺章节", "docs/p11-missing", {
  body: OK_BODY.replace("## 回滚方式\ngit revert <sha>", ""),
});
fail("未填变更定级", "P11: 缺定级", "docs/p11-nograde", {
  body: OK_BODY.replace("- **变更定级**：C1 轻量", ""),
});
fail("勾选不足 7 条", "P11: 勾选不足", "docs/p11-fewchecked", {
  body: OK_BODY.replace(/- \[x\] 第 5 条\n- \[x\] 第 6 条\n- \[x\] 第 7 条/, "- [ ] 第 5 条"),
});
fail("证据区无输出", "P11: 空证据", "docs/p11-noevidence", {
  body: OK_BODY.replace("```\npnpm lint → 0 error, exit 0\n```", "待补"),
});

// ---- 草稿豁免 ----
cases.push({
  name: "Draft PR 跳过校验",
  title: "无任务号的草稿",
  head: "docs/draft-no-id",
  want: 0,
  draft: "true",
});

// ---- 执行 ----
let failed = 0;
for (const c of cases) {
  const got = run(c);
  if (got === c.want) {
    console.log(`OK   ${c.name}`);
  } else {
    failed++;
    console.error(`FAIL ${c.name}：期望 exit ${c.want}，实际 exit ${got}`);
  }
}

console.log(
  failed === 0
    ? `\npr-guard 冒烟全部通过（${cases.length} 例）`
    : `\npr-guard 冒烟 ${failed}/${cases.length} 例失败`,
);
process.exit(failed === 0 ? 0 : 1);
