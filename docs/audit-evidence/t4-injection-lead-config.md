# T4 可审计证据：注射提醒提前天数可配置

- 任务号：T4 · 完成日期：2026-10-27 · 执行/归档：lead
- 需求来源：PRD V1.1 §2.2.3/§2.5.1 + 用户点名 T4 + 裁决⑤（统一提醒配置结构，T6 复用）

## 能力闭环

| 验收项 | 实现 | 证据 |
|--------|------|------|
| 默认 3 天保持兼容 | `ReminderPrefs.defaultInjectionLeads = {3}`；未配置用户行为与旧版一致 | `reminder_prefs_test` 默认用例 |
| 配置持久化 | SharedPreferences `ibd_reminder_injection_leads`（逗号串）；归一化（允许值 0/1/2/3/7、去重升序、空回退默认、损坏串回退默认） | 往返/归一化/损坏 3 用例 |
| 调度读取配置 | `injection_page` 保存排期时读取配置；`scheduleInjectionReminders` 接收集合、每个提前量一条通知 | 代码链 + 调度时刻纯函数 4 用例 |
| 提前 1 天/当天结构 | `Set<int> leads` 集合模型（0=当天），多选 chips UI | `injectionReminderFireTimes({3,1,0})` 用例 |
| 设置页入口 | 「注射提醒（本地）」卡 → 多选 chips 弹窗 → 保存后**立即重排**现有待打提醒，摘要动态显示 | 手工验证步骤见下 |
| 调度计算测试 | 纯函数 `injectionReminderFireTimes`（9:00 偏移、过期回落 now+1min 沿用现状语义） | 4 用例 |

## 测试命令与结果

| 命令 | 结果 |
|------|------|
| `flutter test` | **132/132 PASS**（新增 9：ReminderPrefs 5 + 调度时刻 4） |
| `flutter analyze --no-fatal-infos` | 0 warning / 0 error，11 条 info 与基线一致 |

手工验证步骤（本地通知需真机/模拟器，属既有 BLOCKED 面）：
设置 → 注射提醒（本地）→ 调整提前量（如勾选"当天"）→ 保存 → 文案变为「本地通知（当天 / 提前 3 天）」并出现"已按…重排"提示；注射页重新生成排期后通知按新提前量调度。

## 已知边界 / 后续

- **通知文案含药名/剂量**（现状："请准备 药名（剂量）"）：属本地通知非远程推送，但与约束 §6"通知不含敏感信息"存在张力 → 登记 **T6** 统一处理（脱敏为通用文案）。
- `IbdApiClient.ensureInjectionReminderRule`（服务端 reminder_rules 同步）为**无调用方死代码**，T4 不扩范围；建议 T6 一并决定接入或删除。
- 服务端 `reminder_rules` 表与本地配置暂未同步（本地权威，local-first 语义一致）。
