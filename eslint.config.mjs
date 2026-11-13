// IBD Management Software · ESLint 扁平配置
// 依据：docs/code-review-standard.md §7 G0 门禁
// 设计原则：
//   1. 只开"能指向真实缺陷"的规则，不追求规则数量（标准 §1 原则二：审语义不审风格）。
//   2. 风格类规则全部交给 Prettier（末尾 eslint-config-prettier 关闭冲突项）。
//   3. 类型感知规则仅覆盖有 tsconfig 的目录，避免 "file not found in project" 假报错。
//   4. 存量违规通过 eslint-suppressions.json 基线化，门禁只拦"新增"违规（见 package.json lint 脚本）。
import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import prettier from "eslint-config-prettier";

/** 全局忽略：非 TS/JS 生态、构建产物、生成物 */
const IGNORES = [
  "**/node_modules/**",
  "**/dist/**",
  "**/build/**",
  "**/coverage/**",
  "**/.pnpm/**",
  ".worktrees/**", // git worktree 副本，不是本工作区源码
  "**/var/**", // 本地临时/审阅产物（含 var/scratch 复现脚本）
  "apps/mobile/**", // Flutter/Dart，由 flutter analyze 负责
  "services/parse-worker/**", // Python，由 python 单测负责
  "**/*.d.ts", // 生成物（api-client schema.d.ts 等）
  "apps/miniapp/dist/**",
];

export default tseslint.config(
  { ignores: IGNORES },

  js.configs.recommended,
  ...tseslint.configs.recommended,

  // ---------- 通用 TS 规则（全仓库） ----------
  {
    files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
    rules: {
      // 对应标准 §6 R3：吞异常后继续执行"成功"逻辑
      "no-empty": ["error", { allowEmptyCatch: false }],
      // 对应标准 §6 R13：宽松相等掩盖类型/空值差异
      eqeqeq: ["error", "always", { null: "ignore" }],
      "prefer-const": "error",
      "no-var": "error",
      "no-throw-literal": "error",
      "no-fallthrough": "error",

      // 存量代码大量使用 any；先降级为 warn，避免门禁首日即红
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_", caughtErrors: "none" },
      ],
      // 允许 NestJS 的空构造函数注入写法
      "@typescript-eslint/no-empty-function": [
        "error",
        { allow: ["constructors", "arrowFunctions", "methods"] },
      ],
    },
  },

  // ---------- 类型感知规则：仅限有 tsconfig 覆盖的目录 ----------
  // 这批规则是本项目历史缺陷的直接对应项（异步未等待导致静默失败、Promise 误用）。
  {
    files: [
      "services/api/src/**/*.ts",
      "apps/web/src/**/*.{ts,tsx}",
      "apps/doctor-web/src/**/*.{ts,tsx}",
      "apps/miniapp/src/**/*.{ts,tsx}",
    ],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // 对应标准 §5.6 / R3：async 调用未 await → 失败被丢弃、后续逻辑照跑
      "@typescript-eslint/no-floating-promises": "error",
      // 对应标准 §5.5：把 async 函数直接传给事件回调 / 条件判断
      "@typescript-eslint/no-misused-promises": "error",
      "@typescript-eslint/await-thenable": "error",
      "@typescript-eslint/require-await": "warn",
    },
  },

  // ---------- 服务端（Node） ----------
  {
    files: ["services/**/*.ts"],
    languageOptions: { globals: { ...globals.node } },
  },

  // ---------- 前端（浏览器） ----------
  {
    files: [
      "apps/web/**/*.{ts,tsx}",
      "apps/doctor-web/**/*.{ts,tsx}",
      "apps/miniapp/**/*.{ts,tsx}",
    ],
    languageOptions: { globals: { ...globals.browser } },
    plugins: { "react-hooks": reactHooks },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      // 对应标准 §5.5：依赖缺失导致陈旧状态 / 闭包捕获旧值
      "react-hooks/exhaustive-deps": "warn",
    },
  },

  // ---------- 测试与脚本：放宽 ----------
  {
    files: [
      "**/*.test.ts",
      "**/*.spec.ts",
      "**/scripts/**/*.{ts,mjs,js}",
      "**/*.config.{ts,mjs,js}",
    ],
    rules: {
      "no-console": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-non-null-assertion": "off",
    },
  },

  // ---------- 纯 JS（根 app.js、构建脚本） ----------
  {
    files: ["**/*.{js,mjs,cjs}"],
    languageOptions: { globals: { ...globals.node, ...globals.browser } },
    rules: { "no-console": "off" },
  },

  // 必须放最后：关闭与 Prettier 冲突的格式类规则
  prettier,
);
