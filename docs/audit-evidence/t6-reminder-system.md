# T6 可审计证据：提醒体系补全（用药/复查/当天证件）

- 任务号：T6 · 完成日期：2026-10-27 · 执行/归档：lead
- 需求来源：PRD V1.5 §2.5 + worklist T6 验收 + 用户点名 + T4 移交两项

## 验收闭环

| 验收项 | 实现 | 证据 |
|--------|------|------|
| 三类提醒可创建/取消 | 注射（T4 提前量集合，lead=0=当天档）；**用药**（每日重复，默认关，开关+时刻 0-23 可配，随在用药物数量创建/停药取消）；**复查**（自定义日期提醒，设置页添加/删除） | `reminder_prefs_test` 配置 6 用例 |
| 复用 T4 配置结构 | 全部进 `ReminderPrefs`（SharedPreferences），归一化/损坏回退同款防御 | 同上 |
| 通知内容不含敏感病历 | **全部文案收敛 `reminder_copy.dart` 通用语**（不含药名/剂量/检验/诊断）；当天档="请携带证件与医保卡"；复查档注明"复查项目请遵医嘱"（不给医疗建议）；**禁词表测试固化** | `reminder_copy_test` 3 用例 |
| 调度计算测试 | 纯函数 `medicationDailyAnchor`（今日/明日锚点、时刻归一）、`followupFireTimes`（date+hour、过期跳过、非法过滤） | `reminder_prefs_test` 调度 2 用例 |
| 架构修复 | `ReminderScheduler.syncAll()` 统一入口：一次重排三类（消除"注射重排 cancelAll 清掉用药提醒"隐患）；排期/用药/配置变更后调用 | injection/medication×2/settings 4 个调用点 |

## T4 移交项处置

1. **通知文案脱敏** ✅ — 原"请准备 {药名}（{剂量}）"改为通用语（上表）。
2. **`ensureInjectionReminderRule` 死代码** ✅ — 已删除（无调用方；本地提醒为权威，local-first 语义；服务端 `reminder_rules` 表保留不动）。若后续要服务端提醒规则同步，另立任务接入。

## 测试命令与结果

| 命令 | 结果 |
|------|------|
| `flutter test` | **146/146 PASS**（新增 9：reminder_copy 3 + reminder_prefs 扩展 6） |
| `flutter analyze --no-fatal-infos` | 0 warning / 0 error，9 条 info 与 T5 基线一致（曾引入 1 条 unnecessary_brace，已清理） |

期间修复：`MedicationRepository.listCurrent()` 返回 `List<dynamic>` 的类型映射（编译错误，测试加载即失败暴露）。

## 已知边界

- 每日重复依赖 `matchDateTimeComponents: DateTimeComponents.time`（平台行为），真机验证属既有 BLOCKED（T2.4/T2.5）。
- 用药提醒按"在用药物条数"创建多条每日通知（同一通用文案）；如需合并为一条，后续可优化。
- 复查提醒为用户自定义（不自动生成医疗复查建议——合规约束 §6）。
