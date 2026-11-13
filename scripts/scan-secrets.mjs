#!/usr/bin/env node
/**
 * 敏感信息扫描（G0 的一部分）
 *
 * 兑现 docs/security-checklist.md §1.5「密钥不入库（推送前扫描）」的承诺，
 * 并覆盖 docs/code-review-standard.md §5.4 隐私检查的自动化部分。
 *
 * 扫描范围：
 *   默认  —— 本次变更「新增的行」（PR 模式），避免存量噪声
 *   --all —— 全仓库已跟踪文件（季度审计用）
 *
 * 用法：
 *   node scripts/scan-secrets.mjs
 *   node scripts/scan-secrets.mjs --all
 *   SCAN_BASE_REF=origin/main node scripts/scan-secrets.mjs
 *
 * 设计取舍：宁可少报也不要误报。门禁一旦频繁误报，作者就会习惯性绕过，
 * 等于没有门禁。因此对每类规则都加了「值形态校验」与「本地开发白名单」，
 * 只有高置信度命中才失败。
 *
 * 退出码：0 无发现 / 1 有发现 / 2 执行错误
 */
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";

const ROOT = process.cwd();
const SCAN_ALL = process.argv.includes("--all");

/** 本地/容器内的开发用主机名，连接串里出现不算泄露 */
const LOCAL_HOSTS = new Set([
  "localhost",
  "127.0.0.1",
  "::1",
  "postgres",
  "mysql",
  "mongo",
  "redis",
  "db",
  "host.docker.internal",
]);

/** 值本身像随机串（高熵）才可能是真凭据 */
function looksLikeRealSecret(v) {
  if (typeof v !== "string" || v.length < 16) return false;
  if (/\$\{|\{\{|#\{/.test(v)) return false; // 字符串插值，不是字面量
  if (
    /^(strong-|test|dev-|local|dummy|fake|sample|example|placeholder|change-me|secret-value|storage-secret|jwt-secret|your-)/i.test(
      v,
    )
  ) {
    return false;
  }
  if (/^[a-f0-9]{16,}$/i.test(v)) return true; // 纯 hex（常见密钥形态）
  // 含大小写 + 数字的长随机串
  return /^[A-Za-z0-9+/=_.-]{20,}$/.test(v) && /[A-Z]/.test(v) && /[0-9]/.test(v);
}

/** 连接串：只有非本地主机 + 非空口令才算 */
function isLeakyConnString(line) {
  const m =
    /(?:postgres|postgresql|mysql|mongodb(?:\+srv)?|redis|amqp):\/\/([^:\s/@]+):([^@\s]{3,})@([^/\s:]+)/.exec(
      line,
    );
  if (!m) return null;
  const [, user, pass, host] = m;
  if (LOCAL_HOSTS.has(host.toLowerCase())) return null;
  if (user === pass) return null; // ibd:ibd 这类开发约定
  return pass;
}

const RULES = [
  {
    id: "private-key",
    hint: "私钥内容不得入库",
    // 文档示例与本扫描脚本自身的规则定义不算
    skipFile: /\.(md|markdown|example|txt)$|scan-secrets\.mjs$/i,
    test(line) {
      if (!/-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----/.test(line)) return null;
      // 文档/示例里的占位写法：后接 \n... 或 ...
      if (/\\n\.\.\.|\.\.\./.test(line)) return null;
      // 正则字面量（含 (?: 等语法）不是真实密钥
      if (/\(\?:/.test(line)) return null;
      return "-----BEGIN PRIVATE KEY-----";
    },
  },
  {
    id: "aws-access-key",
    hint: "AWS Access Key ID",
    test: (line) => /\bAKIA[0-9A-Z]{16}\b/.exec(line)?.[0] ?? null,
  },
  {
    id: "google-api-key",
    hint: "Google/Firebase API Key",
    test: (line) => /\bAIza[0-9A-Za-z_-]{35}\b/.exec(line)?.[0] ?? null,
  },
  {
    id: "firebase-private-key",
    hint: "Firebase 服务账号私钥",
    test: (line) => (/"private_key"\s*:\s*"-----BEGIN/.test(line) ? "private_key" : null),
  },
  {
    id: "slack-token",
    hint: "Slack Token",
    test: (line) => /\bxox[baprs]-[0-9A-Za-z-]{10,}/.exec(line)?.[0] ?? null,
  },
  {
    id: "jwt",
    hint: "疑似真实 JWT（令牌不得入库）",
    test(line) {
      const m = /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/.exec(line);
      return m ? m[0] : null;
    },
  },
  {
    id: "db-url-with-password",
    hint: "连接串内含明文口令",
    test: (line) => isLeakyConnString(line),
  },
  {
    id: "assigned-secret",
    hint: "疑似硬编码凭据",
    test(line) {
      const m =
        /(?:secret|password|passwd|pwd|token|api[_-]?key|access[_-]?key|private[_-]?key)\s*[:=]\s*["'`]([^"'`\s]+)["'`]/i.exec(
          line,
        );
      if (!m) return null;
      return looksLikeRealSecret(m[1]) ? m[1] : null;
    },
  },
  {
    id: "cn-id-card",
    hint: "疑似身份证号（真实患者数据不得入库）",
    // 测试/冒烟脚本需要用合成身份证号验证脱敏逻辑（如 skill-community-scrub-smoke），
    // 这类文件不参与本规则；真实业务代码与 fixtures 目录仍会检查。
    skipFile: /(smoke|test|spec|mock|fixture)/i,
    test: (line) =>
      /\b[1-9]\d{5}(?:19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx]\b/.exec(
        line,
      )?.[0] ?? null,
  },
];

/** 占位符/示例/间接引用：不算泄露 */
const ALLOW = [
  /change-me/i,
  /\bYOUR[_-]/i,
  /<[^>]{2,}>/, // <token> / <your-key>
  /\bexample\b/i,
  /\bplaceholder\b/i,
  /\bxxx+\b/i,
  /\bredacted\b/i,
  /\*{4,}/,
  /process\.env\./,
  /\$\{\{\s*secrets\./,
  /\$\{[A-Z_]+\}/,
];

function run(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: ROOT, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  return { ok: r.status === 0, out: r.stdout || "", err: r.stderr || "" };
}

function gitRefExists(ref) {
  return run("git", ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]).ok;
}

function resolveBase() {
  const candidates = [];
  if (process.env.SCAN_BASE_REF) candidates.push(process.env.SCAN_BASE_REF);
  if (process.env.GITHUB_BASE_REF) candidates.push(`origin/${process.env.GITHUB_BASE_REF}`);
  candidates.push("origin/main", "main");
  return candidates.find(gitRefExists) ?? null;
}

/** 返回 [{ file, line, text }]，只含新增行 */
function collectChangedLines() {
  const base = resolveBase();
  if (!base) {
    console.error("[secrets] 无法确定 diff 基线；请用 SCAN_BASE_REF 指定，或改用 --all。");
    process.exit(2);
  }

  // CI 场景看提交差异；本地场景额外看暂存区与工作区，避免"提交前扫不到"
  const diffArgsList = [[`${base}...HEAD`], ["--cached"], []];

  const rows = [];
  for (const extra of diffArgsList) {
    const args = ["diff", "-U0", "--no-color", ...extra, "--", "."];
    const r = run("git", args);
    if (!r.ok) {
      if (extra.length === 1 && extra[0].includes("...")) {
        console.error(`[secrets] git diff 失败：${r.err}`);
        process.exit(2);
      }
      continue;
    }
    rows.push(...parseAddedLines(r.out));
  }

  // 未跟踪的新文件不在 git diff 里，单独全量扫描（本地提交前的主要盲点）
  const untracked = run("git", ["ls-files", "--others", "--exclude-standard"]);
  if (untracked.ok) {
    for (const file of untracked.out.split("\n").filter(Boolean)) {
      if (isBinaryPath(file)) continue;
      try {
        readFileSync(`${ROOT}/${file}`, "utf8")
          .split("\n")
          .forEach((text, i) => rows.push({ file, line: i + 1, text }));
      } catch {
        /* 读不到就跳过 */
      }
    }
  }

  return rows;
}

function isBinaryPath(file) {
  return /\.(png|jpg|jpeg|gif|webp|pdf|ico|woff2?|ttf|jar|so|dylib|dll|exe|zip|gz|db|sqlite)$/i.test(
    file,
  );
}

/** 解析 `git diff -U0` 输出，抽出新增行及其行号 */
function parseAddedLines(diffText) {
  const rows = [];
  let current = null;
  let newLine = 0;

  for (const raw of diffText.split("\n")) {
    if (raw.startsWith("+++ b/")) {
      current = raw.slice(6);
      continue;
    }
    const hunk = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(raw);
    if (hunk) {
      newLine = Number(hunk[1]);
      continue;
    }
    if (raw.startsWith("+") && !raw.startsWith("+++")) {
      rows.push({ file: current, line: newLine, text: raw.slice(1) });
      newLine += 1;
    } else if (!raw.startsWith("-")) {
      newLine += 1;
    }
  }
  return rows;
}

/** 返回 [{ file, line, text }]，全仓库已跟踪文件 */
function collectAllLines() {
  const list = run("git", ["ls-files"]);
  if (!list.ok) {
    console.error(`[secrets] git ls-files 失败：${list.err}`);
    process.exit(2);
  }
  const rows = [];
  for (const file of list.out.split("\n").filter(Boolean)) {
    if (isBinaryPath(file)) continue;
    let content;
    try {
      content = readFileSync(`${ROOT}/${file}`, "utf8");
    } catch {
      continue;
    }
    content.split("\n").forEach((text, i) => rows.push({ file, line: i + 1, text }));
  }
  return rows;
}

function mask(value) {
  const v = String(value).trim();
  if (v.length <= 8) return "*".repeat(v.length);
  return `${v.slice(0, 4)}${"*".repeat(Math.min(12, v.length - 4))}(${v.length})`;
}

const rows = SCAN_ALL ? collectAllLines() : collectChangedLines();
const findings = [];

for (const row of rows) {
  if (!row.text) continue;
  if (ALLOW.some((re) => re.test(row.text))) continue;

  for (const rule of RULES) {
    if (rule.skipFile && row.file && rule.skipFile.test(row.file)) continue;
    const hit = rule.test(row.text);
    if (!hit) continue;
    findings.push({
      file: row.file,
      line: row.line,
      rule: rule.id,
      hint: rule.hint,
      sample: mask(hit),
    });
    break; // 一行只报一次
  }
}

if (findings.length === 0) {
  const scope = SCAN_ALL ? "全仓库" : "本次变更";
  console.log(`[secrets] ${scope}未发现敏感信息（扫描 ${rows.length} 行）。`);
  process.exit(0);
}

console.error(`\n[secrets] 发现 ${findings.length} 处疑似敏感信息：\n`);
for (const f of findings) {
  console.error(`  ${f.file}:${f.line}  [${f.rule}]  ${f.hint}`);
  console.error(`      样本：${f.sample}`);
}
console.error(
  "\n处理方式：\n" +
    "  1. 真实凭据：立即从代码中移除并轮换（视为已泄露），改用环境变量。\n" +
    "  2. 示例/占位符：改用 change-me-* 或 <your-token> 形式，可被白名单识别。\n" +
    "  3. 误报：在 docs/code-review-standard.md §7 登记后调整 scripts/scan-secrets.mjs 白名单。\n",
);
process.exit(1);
