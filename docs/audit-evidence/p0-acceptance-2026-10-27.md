# P0 验收报告（T1–T7）

- 验收日期：2026-10-27 · 执行：lead（独立复核，全部实测重跑）· 签发：**✅ 用户已确认签发（2026-10-27）**
- 范围：Phase 0 第一批 T1–T7（含衍生 T1.1/T1.2 与工程前置 T0.4/T0.5/T0.6）
- 方法：验收点代码抽查（grep/read file:line）+ 全量验证批重跑 + git/worklist 一致性核对；不采信过程报告的口头结论

## 1. 验证批结果（全部实测）

| 命令 | 结果 |
|------|------|
| `flutter test` | **147/147 PASS**（基线 98 → +49） |
| `flutter analyze --no-fatal-infos` | 0 warning / 0 error；9 条 info 全为基线（0 新增） |
| `pnpm build:api` + `pnpm typecheck`（5 包） | PASS |
| API smoke ×7（env/entities/migration/storage/push-copy/skill-community/parse-source） | 全 PASS |
| parse-worker：test_ai_engine / test_lab_data_consistency | ALL_PASS / OK |
| `pnpm audit --prod --audit-level=high` | **0 high/critical**（12 moderate 仅 dev 链遗留，记录在案） |
| `apps/miniapp build:weapp` | Compiled successfully（swiper 12 面） |
| CI（GitHub Actions，e39a92c） | 3 job 全绿（run 40442350404） |

## 2. 逐任务验收点抽查

| 任务 | 验收标准 | 抽查证据 | 判定 |
|------|---------|---------|------|
| T1 bloating | 腹胀独立录入/展示/保存；迁移置空+标记；回归测试 | `symptom_page.dart:246` 独立值；`local_db.dart:395-409` v10 迁移+data_flags；`db_migration_v10_test` 等 8 用例 | ✅ |
| T1.1 语义 B + 补偿 | 仅实际录入才清标记；补偿脚本 | `symptom_page.dart:246`（null 语义）；`docs/migrations/local-db-v10-compensation.sql` 在位（幂等） | ✅ |
| T1.2 疲劳 | 关态不残留滑块值 | `symptom_page.dart:248`（null 语义）；3 用例 | ✅ |
| T2 来源标记 | confirm 不恒写 skill；App 三档；旧数据不回填 | `parse.service.ts:196` resolveLabSource、`:276` 引擎持久化；`lab_entry_page` 三档；9 断言 smoke；兼容说明在证据文档 | ✅ |
| T3 Skill 缓存 | 可读/可命中/可清理；不改服务端契约 | `lab_entry_page.dart:256` load 接入 txt 快速通道；`settings_page.dart:263` clearAll；formatVersion 失效；T3 diff 仅 apps/mobile | ✅ |
| T4 提醒天数 | 默认 {3} 兼容；持久化；调度读配置 | `reminder_prefs.dart:13` 默认 {3}；`reminder_scheduler.dart:13` 调度读取；设置页入口；9 用例 | ✅ |
| T5 患者侧 API | 真实数据；scope 不泄露；空态/错误降级 | `DoctorPatientSource` seam；硬编码演示数据**已消失**（grep `（示例）` 零命中）；revoke 传 grantId；5 用例 | ✅ |
| T6 提醒体系 | 三类可创建取消；无敏感病历；调度测试 | `local_notify.dart:99` rescheduleAll；`reminder_copy` 禁词表测试；死代码仅剩注释；9 用例 | ✅ |
| T7 合规安全 | 声明可见；模板入库（法务 BLOCKED）；checklist | `DisclaimerFooter` 恰好 5 页植入；compliance×2 ⛔ 标注；security-checklist 30 项 | ✅ |

## 3. 工程前置核验

- **git 卫生**：12 个任务各自独立分支 + `--no-ff` 合并链；工作区干净；无跨任务混合提交。
- **worklist**：P8.1 T0–T7（含衍生）全部"已完成"，状态与代码一致；证据文档 `docs/audit-evidence/` 8 份齐全。
- **测试增长**：98 → 147（+49 用例，覆盖全部修复回归面）。

## 4. 发现项（2，均为文档漂移，无代码缺陷）

| # | 发现 | 处置 |
|---|------|------|
| F1 | 遗留 worklist 行 **T6.4（V2 扩展四轨）状态过时**（标"待办"，但勾选历史与代码证实 D1–D4 均已交付） | 本次登记 commit 一并更正为"已完成" |
| F2 | **PRD V1.1 实现状态再度偏差**：T1–T7 后腹胀/提醒体系/声明/患者侧真实 API 等已实现，PRD 标注未跟上 | 建议 P1 开工前做 **PRD v1.2 刷新**（待点名） |

## 5. 遗留 BLOCKED（如实声明，非验收阻塞）

- 真机验收（T2.4/T2.5）与推送真发（T2.1–T2.2 缺 Firebase 凭据）、微信 appid/模板（T3.3/T20）、法务审核（DPIA/知情同意定稿）、swiper 运行时真机验证（SWIPER-R1，截止 2026-11-09）。

## 6. 结论

**P0（T1–T7）验收建议通过**：7/7 任务验收标准全部达成、验证批全绿、无代码级缺陷；2 项文档漂移已处置/已提报。**待用户签发后** P0 关闭，进入 P1（T8–T20）或 PRD v1.2 刷新。
