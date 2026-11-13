#!/usr/bin/env node
/**
 * 增量格式门禁（G0 的一部分）
 *
 * 为什么只查"本次变更的文件"：本仓库有 26k 行存量代码且从未跑过 Prettier，
 * 全量 format:check 必然失败，门禁会永久红。改为只对本次 PR 触碰的 JS/TS/CSS
 * 文件做检查，存量代码在"下次被修改时"自然收敛，无需一次性重排全仓库。
 *
 * 依据：docs/code-review-standard.md §7（G0 门禁）
 * 用法：
 *   node scripts/check-format-changed.mjs                  # 自动推断 base
 *   FORMAT_BASE_REF=origin/main node scripts/check-format-changed.mjs
 */
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const CHECK_EXT = new Set([".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json", ".css", ".html"]);
const SKIP_DIR = [
  "node_modules",
  `${path.sep}dist${path.sep}`,
  `${path.sep}build${path.sep}`,
  `${path.sep}var${path.sep}`,
  ".worktrees",
  "apps/mobile",
  "services/parse-worker",
  "apps/miniapp/dist",
];

function run(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: ROOT, encoding: "utf8" });
  return { ok: r.status === 0, out: (r.stdout || "").trim(), err: (r.stderr || "").trim() };
}

function gitRefExists(ref) {
  return run("git", ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]).ok;
}

function resolveBase() {
  const candidates = [];
  if (process.env.FORMAT_BASE_REF) candidates.push(process.env.FORMAT_BASE_REF);
  if (process.env.GITHUB_BASE_REF) candidates.push(`origin/${process.env.GITHUB_BASE_REF}`);
  candidates.push("origin/main", "main", "HEAD~1");
  for (const ref of candidates) {
    if (gitRefExists(ref)) return ref;
  }
  return null;
}

function changedFiles(base) {
  const names = new Set();

  if (base) {
    const r = run("git", ["diff", "--name-only", "--diff-filter=ACMR", `${base}...HEAD`]);
    if (!r.ok) {
      console.error(`[format] git diff 失败：${r.err}`);
      process.exit(1);
    }
    r.out
      .split("\n")
      .filter(Boolean)
      .forEach((f) => names.add(f));
  }

  // 本地运行：把未提交的改动与未跟踪的新文件也算进来
  for (const args of [
    ["diff", "--name-only", "--diff-filter=ACMR", "--cached"],
    ["diff", "--name-only", "--diff-filter=ACMR"],
    ["ls-files", "--others", "--exclude-standard"],
  ]) {
    const r = run("git", args);
    if (r.ok)
      r.out
        .split("\n")
        .filter(Boolean)
        .forEach((f) => names.add(f));
  }

  return [...names].filter((f) => {
    if (!CHECK_EXT.has(path.extname(f).toLowerCase())) return false;
    const normalized = f.split("/").join(path.sep);
    if (SKIP_DIR.some((d) => normalized.includes(d))) return false;
    if (f.endsWith(".d.ts")) return false;
    if (path.basename(f) === "pnpm-lock.yaml" || path.basename(f) === "eslint-suppressions.json") {
      return false;
    }
    return existsSync(path.join(ROOT, f));
  });
}

const base = resolveBase();
const files = changedFiles(base);

if (files.length === 0) {
  console.log("[format] 本次变更没有需要检查的 JS/TS/CSS 文件，跳过。");
  process.exit(0);
}

console.log(`[format] base=${base ?? "(无，仅本地改动)"}，检查 ${files.length} 个文件`);
files.forEach((f) => console.log(`  - ${f}`));

const prettierBin = path.join(ROOT, "node_modules", "prettier", "bin", "prettier.cjs");
if (!existsSync(prettierBin)) {
  console.error("[format] 未找到 prettier，请先执行 pnpm install。");
  process.exit(1);
}

const res = spawnSync(process.execPath, [prettierBin, "--check", ...files], {
  cwd: ROOT,
  encoding: "utf8",
});

process.stdout.write(res.stdout || "");
process.stderr.write(res.stderr || "");

if (res.status !== 0) {
  console.error(
    "\n[format] 上述文件的格式不符合 .prettierrc.json。\n" +
      "  修复：pnpm exec prettier --write <文件>\n" +
      "  说明：门禁只检查本次变更的文件（见 scripts/check-format-changed.mjs 顶部注释）。",
  );
  process.exit(1);
}

console.log("[format] 通过。");
