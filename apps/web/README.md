# PC Web（V1）

React 18 + TypeScript + Vite + ECharts（后续脚手架）。

## 规划功能

| 功能 | 状态 | 说明 |
|------|------|------|
| **检验套餐模板维护** | **已完成** | 静态页入口：仓库根目录 `index.html` + `styles.css` + `app.js`（浏览器直接打开）。大项/小项 CRUD、排序、导入导出 JSON / Dart 片段，与 `kLabPanels` / `CORE_LAB_NAMES` 对齐 |
| 批量 PDF 解析 | 待完成 | 多文件上传与确认 |
| 完整趋势图表 | 待完成 | 多指标叠加、时间范围 |
| 手术/检查编辑 | 待完成 | 比 App 更完整的表单 |
| 数据导出 | 待完成 | 报告/摘要导出 |

## 检验套餐模板维护（已完成）

入口：仓库根目录 `index.html`（与 `styles.css` / `app.js` 一并）。

实现要点：

- 套餐 = 大项（如「IBD 核心」「血常规」）+ 小项列表
- 小项字段：`nameNorm`（中文规范名，对接趋势/预警）、`nameRaw`、`unit`、`refMin`/`refMax`、排序
- CRUD + 复制套餐 + 导入/导出 JSON；导出 Dart 片段可贴回 `lab_panels.dart` 对齐
- 与 `packages/domain-types` CORE_LAB_NAMES 命名保持一致（UI 标「核心」徽标）
- 数据默认存浏览器 localStorage，不上传

冒烟：`node var/smoke-lab-web.cjs`（6 套餐 / 38 小项）。
