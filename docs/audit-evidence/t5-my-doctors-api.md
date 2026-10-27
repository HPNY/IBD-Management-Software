# T5 可审计证据：患者侧医生建议/审计接真实 API

- 任务号：T5 · 完成日期：2026-10-27 · 执行/归档：lead
- 需求来源：PRD V1.1 §5.1 + T1 审阅问题8 + 用户点名 T5 + 裁决⑥（软件工程规范）

## 验收闭环

| 验收项 | 实现 | 证据 |
|--------|------|------|
| 患者可见真实医生建议与审计 | `my_doctors_page` 全部改走 `/doctor-grants/mine`、`/doctor-patient/notes`、`/doctor-patient/audits`（替换硬编码演示数据）；`DoctorPatientSource` 可注入 seam | `my_doctors_page_test` 渲染用例 |
| scope 不泄露未授权数据 | **服务端零改动**——核实 `doctor-patient/*` 仅按 userId→patientId 过滤返回本人数据；医生侧 `RequireScope` + `scopeAllows` 403 边界已在既有代码；UI 仅渲染拉取的本人数据、确认后 code 服务端脱敏（null）不回显 | 服务端只读核实 + 渲染断言（`授权码 null` 不出现） |
| 空态/错误降级 | 空态三分区文案；加载失败 → 错误横幅 + 重试 + 确认入口保留；确认失败 → 本地行标注「**本地未同步**」（不再伪称 confirmed）；收回失败 → 如实报错不伪称已收回 | 空态/错误态/降级 3 用例 |
| 缺陷修复 | `_revoke` 此前误传 **code**，现传 **grantId**（服务端 `/doctor-grants/:id/revoke` 契约） | revoke 用例断言 `revokedIds == ['grant-abc']` |
| 测试 | 5 用例：真实数据渲染 / 空态 / 错误降级 / revoke 传 grantId / 确认失败诚实降级 | `flutter test` **137/137 PASS** |

## 额外修复（测试暴露的真实缺陷）

- `Unsupported operation: Cannot add to an unmodifiable list`——API/测试源返回不可变列表时降级路径 `insert` 崩溃；改 `List.of()` 归一（`my_doctors_page._loadAll`）。

## 测试命令与结果

| 命令 | 结果 |
|------|------|
| `flutter test` | **137/137 PASS**（新增 5） |
| `flutter analyze --no-fatal-infos` | 0 warning / 0 error；info 9 条（基线 11，重构移除旧页 2 条；0 新增） |

## 已知边界

- 医生侧「执业证核验/扫码授权」仍为既有缺口（PRD §4.2.5 已如实标注，归后续任务）。
- notes/audits 服务端返回全量本人记录（审计 take 100）；分页不在本任务范围。
- 真实 API 联调需服务端运行（本地集成验证经服务端既有 smoke + 本次 UI Fake 测试覆盖；真机联调随 T2.4/T2.5）。
