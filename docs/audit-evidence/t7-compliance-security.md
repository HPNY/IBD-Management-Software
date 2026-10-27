# T7 可审计证据：合规与安全前置

- 任务号：T7 · 完成日期：2026-10-27 · 执行/归档：lead
- 需求来源：PRD V1.1 §4.1 + worklist T7 验收 + 用户点名 + 约束 §6

## 验收闭环

| 验收项 | 实现 | 证据 |
|--------|------|------|
| 非诊断/非治疗声明可见 | `core/ui/disclaimer.dart`（`DisclaimerFooter` + `kNonMedicalDisclaimer`："…非诊断、非治疗建议；用药、复查与治疗决策请遵医嘱"）植入 5 个解读类页面底部 | `disclaimer_test` 1 用例 + 植入清单（下表） |
| DPIA/知情同意模板入 docs | `docs/compliance/dpi-template.md`（数据清单/风险评估/数据主体权利/签批占位）、`docs/compliance/informed-consent-template.md`（A 首次使用/B 云同步/C 医生授权/D 医生注册四触点 + 组件化接入说明） | 文档自身 |
| 法务审核 BLOCKED | 两份模板均标注 ⛔ "待法务审核，不构成合规结论"；未伪造合规状态 | 文档头 |
| 不提交真实个人信息 | 模板全部占位符 `[待填]` + 合成示例 | 文档全文 |
| 生产安全 checklist | `docs/security-checklist.md`：6 节 30 项（环境密钥/服务端/依赖/隐私/传输存储/授权边界）+ 验证命令；状态如实（✅/⬜/⚠️/⛔ 含 DPoP 待启用、DEK 未落地、T21 门禁收紧待办） | 文档 + 来源审计链 |

## 声明植入清单（grep 证据）

| 页面 | 文件 | 植入点 |
|------|------|--------|
| AI/规则分析 | `apps/mobile/lib/features/analysis/ai_rules_page.dart` | ListView 尾部 `DisclaimerFooter` |
| 发作预警 | `apps/mobile/lib/features/analysis/flare_page.dart` | 同上 |
| 药物评价 | `apps/mobile/lib/features/analysis/drug_review_page.dart` | 同上 |
| 食物×排便 | `apps/mobile/lib/features/analysis/food_stool_page.dart` | 同上 |
| 疾病活动度详情 | `apps/mobile/lib/features/home/activity_detail_page.dart` | 同上 |

## 测试命令与结果

| 命令 | 结果 |
|------|------|
| `flutter test` | **147/147 PASS**（新增 1：声明组件渲染 + 文案含"非诊断/非治疗建议/遵医嘱"断言） |
| `flutter analyze --no-fatal-infos` | 0 warning / 0 error，9 条 info 与 T5/T6 基线一致 |

## 已知边界 / 后续

- ⛔ **法务审核 BLOCKED**：DPIA 与知情同意模板须法务定稿后方可宣称合规；A 触点（首启同意）未接入 UI，见模板"组件化使用说明"。
- ⬜ HTTPS 部署核对、密钥部署值核对属部署时人工项（checklist §1/§5）。
- ⛔ 字段级加密（DEK）、T21 门禁收紧、R0.13 DPoP 请求级验签为既有待办（checklist 已标注）。
