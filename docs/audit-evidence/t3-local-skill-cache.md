# T3 可审计证据：App 本地 Skill 缓存可读/可命中/可清理

- 任务号：T3 · 完成日期：2026-10-27 · 执行/归档：lead
- 需求来源：PRD V1.1 §2.1.1（"越用越准"端上快路径）+ T1 审阅 M3（缓存只写不读）+ 用户点名

## 能力闭环

| 能力 | 实现 | 证据 |
|------|------|------|
| 可读 | `LocalSkillStore.load()` 接入 txt 快速通道（此前零调用方） | `lab_entry_page._consentAndFill` |
| 可命中 | `skill_matcher.dart` 纯函数：文本报告按缓存规则提取检验项，**全部规则命中**才走本地通道（`isFullHit`）；部分/零命中回落云端（安全回退）；命中走 `engine: 'skill'`，与 T2 来源标记语义闭环 | `skill_matcher_test` 6 用例 |
| 可清理 | `clear()/clearAll()` + 设置页「AI 解析」卡清理按钮（确认弹窗，注明只删模板缓存不删检验数据） | `local_skill_store_test` 清理 2 用例 |
| 可失效 | 缓存写入 `formatVersion`；`load()` 对旧缓存（无版本号）/损坏 JSON/版本不识别一律返回 null → 走云端 | 失效 2 用例 |
| 不改服务端契约 | 本地命中仅影响 txt 预填路径；PDF/图片与未命中走原云端链路（consent/上传/用完即删不变）；服务端零改动 | diff 仅 apps/mobile + docs |

## 测试命令与结果

| 命令 | 结果 |
|------|------|
| `flutter test` | **123/123 PASS**（新增 12：skill_matcher 6 + local_skill_store 6） |
| `flutter analyze --no-fatal-infos` | **0 warning / 0 error**，11 条 info 与基线一致（曾引入 2 条 use_build_context_synchronously，已用 mounted 守卫修复并复测清零） |

## 已知边界

- 快速通道仅对 `.txt` 文本报告生效（PDF/图片无本地文本，云端解析不变）。
- 全命中才走本地（医疗数据宁可回落云端）；命中 banner 明示"文件未上传"。
- 旧格式缓存视为失效需重新确认生成（无迁移负担）。
- 设置页清理按钮为 UI 粘合层，逻辑由 store 单测覆盖；未加 settings widget 测试（该页 provider 依赖重），手工验证步骤：设置 → AI 解析 → 删除图标 → 确认 → 计数归零。
