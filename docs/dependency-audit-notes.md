# 依赖审计已知项记录（T0.4）

- 任务号：T0.4（裁决：开工 / 2a 门禁改 `--prod` / 3a swiper override）
- 日期：2026-10-26
- 门禁现状：CI 执行 `pnpm audit --prod --audit-level=high`，**生产依赖 high+ 为零**（余 12 moderate）。
- 全量审计基线：106 个（9 low / 54 moderate / 38 high / 5 critical）→ 治理后 73 个（7 low / 46 moderate / 18 high / 2 critical）。

## 已治本（pnpm overrides，见根 package.json）

生产链：body-parser 1.20.9、multer 2.5.0、proxy-addr 2.0.8、source-map-js 1.2.2、lodash/lodash-es 4.18.1、brace-expansion@2 2.1.7、js-yaml@4 4.3.2、form-data@2 2.5.6、swiper 12.2.0（裁决 3a）。
dev 链 patch 级：follow-redirects 1.16.x、glob@10 10.5.x。
多主版本包均采用定向 override（`pkg@<major>`），其它主版本（js-yaml@3、form-data@4、brace-expansion@1、glob@7）未受影响（锁文件已核验）。

## 已知 dev 构建链遗留项（不阻塞 --prod 门禁；随工具链升级任务复查）

| 包 | 级别 | 现版本 | 处置说明 |
|----|------|--------|---------|
| decompress | critical | Taro CLI 链 | **无补丁版本**（上游未修），dev-only |
| node-forge | high | Taro webpack5-runner 链 | **无补丁版本**，dev-only |
| git-clone | high | Taro CLI 链 | **无补丁版本**，dev-only |
| html-minifier | high | Taro webpack5-runner 链 | **无补丁版本**，dev-only |
| vite | high | 5.4.x | 补丁仅 >=6.4.3，需 Vite 大版本升级（web/doctor-web 工具链） |
| webpack-dev-middleware | high | 5.x | 补丁仅 >=7.4.6，随 webpack 工具链升级 |
| serialize-javascript | high | 6.x | 补丁仅 >=7.0.3，随 webpack 工具链升级 |
| http-cache-semantics | high | 3.x | 补丁仅 >=4.1.1，3.x 线无补丁，随 webpack-dev-middleware 升级 |
| postcss | high | 7.x（旧工具链） | 补丁仅 >=8.5.12，随 Taro/webpack 工具链升级 |
| tmp | high | 0.0.x | 补丁仅 >=0.2.6，随 Taro CLI 升级 |
| adm-zip | high | 0.4.x | 补丁 >=0.6.0（0.x 线兼容风险），随 Taro CLI 升级 |

> 以上全部位于 `apps/miniapp` 的 Taro 构建工具链（devDependencies 或其传递依赖），不进入生产运行时。

## 验证状态与 BLOCKED

- ✅ `pnpm audit --prod --audit-level=high`：0 high/critical（12 moderate）。
- ✅ `pnpm build:api`、全仓 `pnpm typecheck`（5 包）、6 项 API smoke：全过。
- ✅ **swiper 12 override 构建集成验证（T0.5 内完成，符合"限期验证"裁决）**：miniapp 构建已修复（补 babel.config.js + babel-preset-taro + 工作区 TS loader 规则），`build:weapp` 编译成功，产物 `dist/taro.js` 含 swiper 12.2.0 编译代码、`dist/common.js` 含 @ibd/api-client 运行时代码。
- ⚠️ 遗留（既有 BLOCKED）：swiper 12 的**运行时**行为需微信开发者工具/真机验证，随 T2.4/T2.5 真机验收执行。

## 后续建议

- ~~T0.5：修复 miniapp 构建~~ **已完成**（2026-10-26，`task/t0.5-miniapp-build-fix`）。
- T21（裁决 3，P1 之后执行）：dev 工具链升级（Taro/Vite/webpack 链）消化上表遗留项，**完成后门禁收紧回全量 `pnpm audit --audit-level=high`**。
