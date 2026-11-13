#!/usr/bin/env node
/**
 * PR 守卫（硬规则 1 的可执行实现）
 *
 * 校验 docs/code-review-process.md §4 步骤 0/2 的两条前置要求：
 *   1. 无任务号不开 PR
 *   2. PR 描述必须包含规定章节，且自查清单已勾选、变更定级已填写
 *
 * 为什么放在 CI 而不是靠自觉：本仓库 197/199 次提交来自 AI 代理，
 * 靠提醒无法保证；只有让"缺任务号的 PR 直接红"才成立。
 *
 * 由 .github/workflows/pr-guard.yml 调用，读取以下环境变量：
 *   PR_TITLE / PR_HEAD_REF / PR_BODY / PR_NUMBER / PR_AUTHOR / PR_IS_DRAFT
 */
const title = process.env.PR_TITLE ?? "";
const headRef = process.env.PR_HEAD_REF ?? "";
const body = process.env.PR_BODY ?? "";
const prNumber = process.env.PR_NUMBER ?? "?";
const author = process.env.PR_AUTHOR ?? "?";
const isDraft = (process.env.PR_IS_DRAFT ?? "").toLowerCase() === "true";

/** 任务号形态：T8.2 / T0.3 / F1 / G2（与 docs/session-worklist.md 一致） */
const TASK_RE = /\b(?:T\d+(?:\.\d+)?|F\d+(?:\.\d+)?|G\d+)\b/;

/** PR 描述必须出现的章节（与 .github/pull_request_template.md 对齐） */
const REQUIRED_SECTIONS = ["变更概要", "影响范围", "证据", "自查清单", "回滚方式"];

/** 自查清单至少勾选条数（模板中「通用」组共 7 条，这是最低要求） */
const MIN_CHECKED = 7;

const problems = [];
const notes = [];

// ---- 规则 1：任务号 ----
const inTitle = TASK_RE.test(title);
const inBranch = TASK_RE.test(headRef);
const branchConvention = /^(task|fix|feature|docs|chore)\/[A-Za-z0-9._-]+$/.test(headRef);

if (!inTitle && !inBranch) {
  problems.push(
    "缺少任务号：PR 标题或分支名中必须包含任务号（形如 T8.2 / T0.3 / F1 / G2）。\n" +
      `    当前标题：「${title || "(空)"}」  当前分支：「${headRef || "(空)"}」\n` +
      "    依据：docs/code-review-process.md §4 步骤 0「没有任务号的 PR 直接关闭」",
  );
} else {
  const found = (title.match(TASK_RE) ?? headRef.match(TASK_RE) ?? [])[0];
  notes.push(`任务号：${found}`);
}

if (headRef && !branchConvention) {
  notes.push(
    `分支命名不符合约定「task/<任务号>-<简述>」：当前为「${headRef}」（依据 engineering-constraints.md §4）`,
  );
}

// ---- 规则 2：PR 描述完整性 ----
if (!body.trim()) {
  problems.push("PR 描述为空：请使用 .github/pull_request_template.md 填写后再提交审查。");
} else {
  const missing = REQUIRED_SECTIONS.filter((s) => !body.includes(s));
  if (missing.length > 0) {
    problems.push(
      `PR 描述缺少章节：${missing.join("、")}\n` +
        "    请从 .github/pull_request_template.md 补齐，不要删除模板章节。",
    );
  }

  // 变更定级
  const gradeMatch = /变更定级[\s\S]{0,60}?\bC[1-4]\b/.exec(body);
  if (!gradeMatch) {
    problems.push(
      "未填写变更定级：请标注 C1 / C2 / C3 / C4（判定标准见 docs/code-review-standard.md §3）。",
    );
  } else {
    notes.push(`变更定级：${/C[1-4]/.exec(gradeMatch[0])[0]}`);
  }

  // 自查勾选
  const checked = (body.match(/^\s*[-*]\s*\[[xX]\]/gm) ?? []).length;
  if (checked < MIN_CHECKED) {
    problems.push(
      `自查清单勾选不足：已勾选 ${checked} 条，至少需要 ${MIN_CHECKED} 条。\n` +
        "    勾选必须附证据（命令 + 输出 / 测试名 / 文件路径），无证据的勾选视为未完成。",
    );
  } else {
    notes.push(`自查勾选：${checked} 条`);
  }

  // 证据区不能是空的占位
  const evidenceEmpty = /##\s*证据[\s\S]{0,200}?(?=##|$)/.exec(body);
  if (evidenceEmpty && !/(```|passed|PASS|通过|exit|✅)/i.test(evidenceEmpty[0])) {
    problems.push(
      "证据区为空：至少贴一条门禁命令及其输出摘要（不要只写「已测试」）。\n" +
        "    依据：docs/code-review-standard.md §7 G1「无证据的勾选视为未完成」",
    );
  }
}

// ---- 输出 ----
const header = `PR #${prNumber}（作者：${author}）`;
if (isDraft) {
  console.log(`${header} 为 Draft，跳过守卫校验。转为 Ready for review 后会重新检查。`);
  process.exit(0);
}

if (problems.length === 0) {
  console.log(`${header} 通过 PR 守卫。`);
  notes.forEach((n) => console.log(`  · ${n}`));
  console.log("\n下一步：等待 G0 机器门禁（lint / typecheck / smoke / test）全绿后进入人工审查。");
  process.exit(0);
}

console.error(`\n${header} 未通过 PR 守卫（硬规则 1）：\n`);
problems.forEach((p, i) => console.error(`  ${i + 1}. ${p}\n`));
console.error(
  "参考：docs/code-review-process.md §4 步骤 0/2 · 模板：.github/pull_request_template.md\n",
);
process.exit(1);
