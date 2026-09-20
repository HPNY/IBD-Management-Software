# PC Web（V1）

React 18 + TypeScript + Vite + ECharts。

## 规划功能

| 功能 | 状态 | 说明 |
|------|------|------|
| 批量 PDF 解析 | 待完成 | 多文件上传与确认 |
| 完整趋势图表 | 待完成 | 多指标叠加、时间范围 |
| 手术/检查编辑 | 待完成 | 比 App 更完整的表单 |
| 数据导出 | 待完成 | 报告/摘要导出 |
| **检验套餐模板维护** | **待完成** | 维护大项/小项：规范名、单位、参考范围、排序、自定义套餐；供 App 手动录入等使用。当前 App 为内置模板（`apps/mobile/lib/core/lab/lab_panels.dart`） |

## 检验套餐模板维护（待完成 · 产品已确认）

作为 PC 端功能之一，后续实现要点（待设计）：

- 套餐 = 大项（如「IBD 核心」「血常规」）+ 小项列表
- 小项字段：`nameNorm`（中文规范名，对接趋势/预警）、`nameRaw`、`unit`、`refMin`/`refMax`、排序
- CRUD + 导入/导出；可与 App 本地模板对齐或下发
- 与 `packages/domain-types` CORE_LAB_NAMES 命名保持一致
