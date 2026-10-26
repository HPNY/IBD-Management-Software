# T2 可审计证据：检验来源标记（skill|ai|manual）如实化

- 任务号：T2 · 完成日期：2026-10-26 · 执行/归档：lead
- 需求来源：PRD V1.1 §2.1.1/§3.2（附录 #2）+ 用户点名 T2 + 裁决④（旧数据不回填）

## 修复内容与证据

| 项 | 修复前 | 修复后 | 证据 |
|----|--------|--------|------|
| 服务端 confirm 写 source | 恒写 `skill` | 按任务真实引擎写 `skill\|ai` | `services/api/src/modules/parse/parse.ts`（resolveLabSource） |
| worker 引擎信息 | 丢弃（ParseJob 无 engine） | 持久化 `parse_jobs.engine`（skill\|ai-empty→ai） | 迁移 `1727600000000-AddParseJobEngine.ts` + `markCompleted` |
| App 保存 source | 只有 `ai\|manual` | `skill\|ai\|manual` 三档（`seedParsedEngine`/job.engine） | `lab_entry_page.dart`、`ibd_api_client.dart` ParseJobDto.engine |
| 契约 | — | `ParseJobDto.engine?: string\|null`（可选新增，向后兼容） | `packages/api-client/src/index.ts` |

## 兼容策略（裁决④：旧数据不回填）

1. **旧 LabResult**：`source` 保持原值不动（不回填、不迁移）。
2. **旧解析任务**（迁移前、`engine` 为 NULL）：confirm 时按 `skillVersionId` 是否存在回退判定（Skill 命中才写 skillVersion → `skill`；否则 `ai`），与修复前客户端行为一致。
3. **API 响应**：`engine` 为可选新增字段，旧客户端忽略即可；无破坏性变更。
4. **迁移**：可空列 + `up/down`（DROP COLUMN）；迁移冒烟含行为级探针（缺省 engine 插入回读 NULL）。

## 测试命令与结果（2026-10-26）

| 命令 | 结果 |
|------|------|
| `pnpm --filter @ibd/api smoke:parse-source`（9 断言矩阵） | **PASS** |
| `pnpm --filter @ibd/api smoke:migration`（含 engine 行为级可空探针） | **PASS** |
| 其余 5 项 API smoke（env/entities/storage/push-copy/skill-community） | **PASS** |
| `pnpm build:api` + `pnpm typecheck`（5 包） | **PASS** |
| `flutter test` | **111/111 PASS**（含新增"Skill 引擎解析结果入库 source=skill"用例；既有 `source=ai` 用例验证无引擎信息时回退 `ai`） |
| `flutter analyze --no-fatal-infos` | 0 warning / 0 error（11 条基线 info） |

## 已知边界

- App 端经 `seedParsedItems`（测试注入）或云端解析（job.engine）获得引擎；经本地 Skill 缓存直填的路径不产生解析任务，保存归 `manual`（与语义一致）。
- 服务端 confirm 恒由解析任务产生，故不出现 `manual`（manual 仅客户端直录）——三值枚举在两侧各自语义自洽。
