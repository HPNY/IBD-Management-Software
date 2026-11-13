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

## 证据 E · 2026-11-13 静态取证（覆盖「运行时污染」假设，不覆盖真机渲染）

背景：截止日 2026-11-09 已逾期，用户 2026-11-13 裁决「继续限期验证，不回滚 override」。本轮先做不需要真机的静态取证。

### E1 · override 确实生效

`pnpm why swiper -r`（`task/ui-review-u1u17` @ `89f6109`）：

```
@ibd/miniapp@0.1.0
dependencies:
@tarojs/components 3.6.34
└── swiper 12.2.0
@tarojs/plugin-platform-weapp 3.6.34
└─┬ @tarojs/components 3.6.34 peer
  └── swiper 12.2.0
```

即 `@tarojs/components@3.6.34` 的 `package.json` 虽声明 `"swiper": "6.8.0"`，实际解析到根 `pnpm.overrides` 的 `^12.1.2` → **12.2.0**。`node_modules/.pnpm/swiper@12.2.0/` 存在，无 6.8.0 副本。

### E2 · 小程序源码不使用 Swiper 组件

`Select-String -Path apps/miniapp/src/**/*.tsx,*.ts -Pattern "Swiper|swiper"` → **0 命中**。小程序 5 个页面（index/checkin/injection/labs/summary）与 `lib/api.ts`、`wx_auth.ts` 均无 Swiper 引用。

### E3 · weapp 产物不含 swiper 12 运行时

`pnpm --filter @ibd/miniapp build:weapp` → `Compiled successfully in 9.70s`，产物 `apps/miniapp/dist/`。

`swiper` 在 `dist/*.js` 中仅 **7 处，全部位于 `taro.js`**：

| 位置 | 内容 | 性质 |
|------|------|------|
| 15263 / 15319 | `Swiper:{"snap-to-edge":u,"easing-function":"'default'"},SwiperItem:{"skip-hidden-item-layout":u}` | 组件属性映射表 |
| 38984 | `""!==u&&"swiper-item"!==n&&(i["st"]=u)` | hydrate 时的样式判断 |
| 106403 / 106412 | `ScrollView:V,Swiper:W,SwiperItem:H,Navigator:z` | 组件名 → 实现映射 |
| 107035 / 107048 | `["scroll-view",4],["swiper",4],["swiper-item",4]` | 标签名表 |

**以下 swiper 12 运行时符号在 `dist/*.js` 中全部 0 命中**：`SwiperCore`、`swiper-wrapper`、`swiper-container`、`swiper-slide`、`swiper-button-next`、`slidesPerView`、`wrapperEl`、`slidesEl`、`onAny`、`swiperSlideSize`、`watchSlidesProgress`、`virtualTranslate`、`params.watchOverflow`、`Swiper/A11y`、`swiper/modules`、`swiper/dist`。

`@tarojs/components` 中引用 swiper 的文件仅为 stencil/web-components 路径：`dist/cjs/taro-swiper-core_2.cjs.entry.js`、`dist/collection/components/swiper/swiper.js`、`dist/esm/taro-swiper-core_2.entry.js`、`dist/hydrate/index.js`、`dist/taro-components/p-87b0d22f.entry.js` —— 这些是 **web 平台**产物，weapp 平台不加载。

旁证：`hammer` / `hls.js` / `stencil` 在同一批 `dist/*.js` 中同样 0 命中（`IntersectionObserver` 2 处、`snap-to-edge` 1 处属 Taro 自身实现）。

### E4 · 仍未闭环的部分

| 矩阵项 | 状态 | 原因 |
|--------|------|------|
| ① Tab 渲染与切换 | ⏳ | 需微信开发者工具或真机 |
| ② 滚动/列表交互（swiper 运行时污染） | ✅ 产物层面已证伪（E3） | —— |
| ③ 订阅消息/登录页打开 | ⏳ | 依赖微信 appid（T20 阻塞） |
| ④ 冷启动 + 弱网 | ⏳ | 需真机 |
| 微信基础库 ≥2.30 兼容 | ⏳ | 本机无微信开发者工具（`C:\Program Files (x86)\Tencent\微信web开发者工具\cli.bat`、`C:\Program Files\Tencent\...`、`%LOCALAPPDATA%\Programs\...` 三路径 `Test-Path` 均 False） |

结论：场景 ② 的风险假设已被产物证据推翻；其余三项仍需真机/开发者工具环境，本项**不得**据此标记完成。

### E5 · 复现命令（可重跑）

```powershell
pnpm why swiper -r
Select-String -Path apps/miniapp/src/**/*.tsx -Pattern "Swiper"
$env:http_proxy=''; pnpm --filter @ibd/miniapp build:weapp
foreach ($p in @('SwiperCore','swiper-wrapper','slidesPerView','wrapperEl','watchSlidesProgress')) {
  "$p => $((@(Select-String -Path apps/miniapp/dist/*.js -Pattern $p -AllMatches)).Count)"
}
```

