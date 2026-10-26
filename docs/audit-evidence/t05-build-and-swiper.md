# T0.5 可审计证据：miniapp 构建修复两层根因 + swiper 12 集成验证

- 任务号：T0.5 · 归档日期：2026-10-26 · 归档人：lead
- 原始日志：`var/logs/miniapp-build*.log`（gitignore 目录，本文件摘录关键段落作为持久证据）
- 复现基线命令（证据 A 即由此产生）：
  `git stash --include-untracked && pnpm install --frozen-lockfile && pnpm --filter @ibd/miniapp build:weapp`

## 证据 A · 修复前基线失败（babel 配置缺失层）

时间：2026-10-26 17:16 · exit=1

```
ModuleBuildError: Module build failed (from .../babel-loader/lib/index.js):
SyntaxError: C:\...\apps\miniapp\src\app.ts: Unexpected token, expected "," (4:25)
Compiled with some errors in 2.84s
Exit status 1
```

说明：`src/app.ts`（实为含 TSX 的 App 入口）被 babel-loader 按纯 JS 解析——`git log --all -- apps/miniapp/babel.config.js` 为空，仓库从未包含 babel 配置。**该失败在无 override 基线上同样复现**（stash 对照），与 T0.4 依赖 override 无关。

## 证据 B · 第二层失败（工作区 TS 包无 loader）

补 babel.config.js + babel-preset-taro 后：exit=1 · `var/logs/miniapp-build.log:137-143`

```
ModuleParseError: Module parse failed: Unexpected token (5:8)
You may need an appropriate loader to handle this file type,
currently no loaders are configured to process this file.
|
| // 无 @types/node：窄化 process 形状，兼容浏览器 typeof 守卫。
> declare const process:
|   | { env?: Record<string, string | undefined> }
```

说明：`packages/api-client/src/index.ts`（TS 源码）经 workspace 引用进入打包，Taro 默认 babel-loader 不覆盖 `packages/**`。

## 证据 C · 第三步失败（pnpm 严格树下 babel-loader 不可解析）

加 workspace-ts 规则后：exit=1 · `var/logs/miniapp-build2.log:134-158`

```
resolve 'babel-loader' in 'C:\...\apps\miniapp'
  ... C:\...\apps\miniapp\node_modules\babel-loader doesn't exist
```

## 证据 D · 最终成功 + swiper 集成验证

补 `babel-loader@^8` devDep 后：exit=0 · `var/logs/miniapp-build3.log:144`

```
Compiled successfully in 7.73s
```

产物核验（`apps/miniapp/dist/`）：

| 检查项 | 方法 | 结果 |
|--------|------|------|
| swiper 12.2.0 进产物 | `Select-String dist\*.js -Pattern 'swiper' -List` | 命中 `taro.js` ✅ |
| @ibd/api-client 运行时进产物 | 同上 `-Pattern 'IBD_API_BASE|presign'` | 命中 `common.js` ✅ |
| 产物结构 | dist 目录清单 | app.js/taro.js/common.js/pages/… 正常 ✅ |

## swiper 12 运行时真机验证矩阵（裁决：限期验证、不直接豁免）

| 项 | 内容 |
|----|------|
| Owner | lead（协调）· 真机执行人**待指派**（需 Android/iOS 设备） |
| 截止日 | **2026-11-09**（逾期未验 → 立即上报裁决，不自行豁免） |
| 版本面 | Taro 3.6.34 · swiper 12.2.0（override）· 微信基础库 ≥2.30 |
| 设备矩阵 | Android ≥10 一台 + iOS ≥15 一台（或微信开发者工具先行） |
| 验证场景 | ① 首页/打卡/注射/分析 Tab 渲染与切换；② 页面滚动与列表交互（swiper 组件随 @tarojs/components 打包，需确认无运行时污染）；③ 订阅消息/登录页打开；④ 冷启动 + 弱网 |
| 证据归档 | 命中问题时：截图/控制台日志 + 本文追加结论段 |
| override 到期日 | 与截止日同（2026-11-09）：届时无结论 → 上报，二选一裁决（继续保留 / ignoreCves 豁免） |
| 回滚预案 | ① 删 `package.json` 的 `"swiper": "^12.1.2"` override + `pnpm install`（回到 6.8.0，**注意 critical 漏洞复现**，需同步走豁免裁决）；② 或保留 override + `pnpm.auditConfig.ignoreCves` 记录（裁决后执行）；均 revert 单 commit 可回退 |
