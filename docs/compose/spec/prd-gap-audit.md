---
feature: prd-gap-audit
status: delivered
updated: 2026-09-23
branch: feature/prd-gap-audit
commits:
---

# PRD × 当前代码差距审阅

## Report

**What was built** — 全量对照 PRD 与当前代码/架构/worklist，形成本 spec：无 Critical 新代码 bug；识别 4 类矛盾/Partial（无登录墙 vs PRD 登录、小程序 P0、年报自动生成、SF-36 简化计分）与 6 条漏记 Gap（G1–G6）。G1–G6 已写入 `docs/session-worklist.md`；矛盾以本 [S2.2] 为权威对照，不改 PRD 正文。

**Verification** — Python 计数：清单 G1–G6 各出现 1 次；spec frontmatter `status: in-progress`→交付前改 delivered；无代码测试（纯文档）。基线 `origin/main` `7ae3fd4`。

**Journey log** — PRD 里程碑 V1.5 与 worklist「已完成」项大体重合，易漏的是日记字段/仪表盘组件/年报同比/Excel；local-first 与 PRD 登录体系冲突需产品择时回写 PRD，否则对照表会持续假阴性。

## [S1] Problem

PRD（949 行）定义了 MVP→V2.0 全里程碑；仓库已有 v0.1.0 本地优先实现与 `session-worklist` 遗留项，但缺少一份**权威的 PRD↔实现对照**，难以回答「是否存在问题、还差什么、是否自相矛盾」。需要固定差距清单与可验证任务，避免跨会话丢失。

## [S2] Design

### S2.1 审阅结论（问题分类）

| 类级 | 含义 | 本轮判定 |
|------|------|----------|
| **Critical 代码 bug** | 当前实现错误/安全/编译失败 | **无新增**（此前已修 IDOR、analyze、锁文件等） |
| **Contradiction** | PRD 与产品决策/架构互相冲突 | 有，需书面承认或改 PRD |
| **Gap · 里程碑未完成** | PRD 要求但代码未做 | 有，分「已记 worklist」与「漏记」 |
| **Partial** | 已做但弱于 PRD | 有 |

### S2.2 Contradiction（PRD vs 产品决策）

| # | PRD | 实际决策 | 状态 |
|---|-----|----------|------|
| C1 | 全端共用「微信登录/手机号登录」账号体系（§4.2.7） | local-first：**无登录墙**，仅可选关联手机号/微信 | **已决策**（Phase0 冻结）· PRD 未改 |
| C2 | 小程序 P0 与 MVP 并行（§4.2.8） | 架构里程碑把小程序壳放 MVP，功能可后置；T3.1–3.2 已补壳 | **部分对齐** |
| C3 | 年报「自动生成」（§2.6.2） | 实现为**用户手动触发**生成 | **Partial** · 建议改文案或加定时 |
| C4 | SF-36 标准计分 | 实现 0–4 简化计分供自管趋势 | **Partial** · 已在 UI 声明 |

### S2.3 Gap · 漏记 worklist 的 PRD 能力

| ID | PRD 锚点 | 能力 | 里程碑 |
|----|----------|------|--------|
| G1 | §2.6.1 | 疾病活动度仪表盘：CRP/ESR/钙卫**状态灯**、Limberg、SES-CD、用药卡、倒计时 | V1.5 |
| G2 | §2.7.1 | 症状日记补：**口腔溃疡、关节痛+部位、自定义项**；日历热力；快捷模板「和昨天一样」 | V1.5 |
| G3 | §2.6.2 | 年报**与上一年度对比**、检查/手术汇总列 | V1.5 |
| G4 | §4.2.2 | **睡眠/压力**每日打卡（App 功能表） | V1.5/2 |
| G5 | §4.2.4 | PC **Excel 导出**（现仅 JSON/CSV）、Skill 模板管理表单 | V1.5 |
| G6 | §2.7.2 | 食物-排便关联分析入口 | V2.0 |

### S2.4 Gap · 已在 worklist（对照确认）

T2.1–2.5 推送/真机、T3.3 微信模板、T6.1 Skill 社区、T6.2 医生端、T6.4 V2 四项、T2.7 Web tsc —— 见 [session-worklist](../../session-worklist.md)。

### S2.5 Partial · 已实现但弱于 PRD

| 项 | PRD | 现状 |
|----|-----|------|
| 发作预警 | AI + 症状模式 | 规则型 flare（可用，非 ML） |
| 双引擎解析 | Skill + LLM/Vision 兜底 | Skill + LLM；Vision/OCR 视 scan 质量 |
| 可用性 | 大字体/简洁/中英 | 已做（T7） |
| 量表 | SF-36 等 | 已做，SF-36 简化计分 |

### S2.6 里程碑对照摘要

| 阶段 | PRD 要求 | 代码状态 |
|------|----------|----------|
| MVP | 检验+PDF、用药、注射、日记 | **完成**（日记字段见 G2） |
| V1.0 | 检查/手术、时间线、趋势、排便 | **完成** |
| V1.5 | 摘要、年报、导出、发作、量表 | **大部完成** · G1/G3/G5/G2 部分缺 |
| V2.0 | 医患、AI 分析、饮食、药物评价、同城 | **未开始** · worklist T6.2/T6.4 |

## [S3] Out of Scope

- 不改 PRD 原文（矛盾记录即可，是否回写产品文档另议）
- 不本轮实现 G1–G6（仅入清单）
- 不解决 T2 凭据 / 真机阻塞

## Tasks

- [x] T1: 将 G1–G6 写入 session-worklist — acceptance: 清单含 6 条待办且 ID/验收齐全 (covers: S2.3)
- [x] T2: 文档注明 C1–C4 矛盾/部分差异 — acceptance: 本 spec [S2.2] 即为权威对照，README 不改 PRD 正文 (covers: S2.2)
- [ ] T3: （后续）按清单实现 G1–G5 — acceptance: 对应 PRD 锚点主路径可验收 (covers: S2.3; depends: T1)

