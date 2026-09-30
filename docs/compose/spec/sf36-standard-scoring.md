---
feature: sf36-standard-scoring
status: delivered
updated: 2026-09-23
branch: feature/sf36-standard-scoring
commits: 978d1c5..91e0777
---

# SF-36 标准 8 维计分（G7）

## Report

**What was built** — SF-36 在保留简化 0–4 合计（0–144，含变化题）的同时并行输出标准 8 维 0–100 域分。新增纯函数 `sf36_scoring.dart`：固定 36 题索引映射（变化题不入域），域分 = `round(100×sum/(4×n))`，`stdAverage` 为 8 域算术均（不称 PCS/MCS）。量表页实时预览 8 维 chip 与均分；保存写入 `detail_json` 的 `scoring: v1-parallel` / `domains` / `stdAverage`；历史卡片显示均分与最弱 2 维。intro 文案改为「并行标准 8 维 + 简化合计」。

**Verification** — `flutter test` PASS **69**（含 `sf36_domain_score_test` 6 项：映射覆盖、全 0/全 4、round 边界、stdAverage、简化合计、越界 ArgumentError）；`flutter analyze --no-fatal-infos` PASS（7 infos 为既有 prefer_const，与本次无关）。独立审阅 **APPROVE**，无 critical。

**Journey log** — 用户裁定并行而非替换，历史简化分趋势不断档；题干/0–4 选项未改，故无需反向计分（方向已统一高分好）。`sf36Domains.byId` 为唯一真相，题序若改必须同步映射。历史 `detail_json` 仍用正则解析（与既有 band 一致）；后续可改 `jsonDecode`。本机 `flutter test` 需 `ProgramFiles(x86)` 环境变量。

## [S1] Problem

PRD §2.7.4 要求 SF-36 用于生活质量纵向评估；用户裁定 C4 要求**补齐标准 SF-36 计分**。当前实现（`survey_kit.dart` / `survey_page.dart`）为统一 0–4 五档合计分（0–144）+ 简易分档，**无 8 维 0–100 域分**，无法对照 SF-36 标准域（PF/RP/BP/GH/VT/SF/RE/MH）解读。

用户决策（2026-09-23）：
1. **并行标准分**：保留简化 0–4 合计与历史趋势，同时输出标准 8 维分。
2. **保留现有题干 + 五档选项**：不改题面与 0–4 锚点，仅增加域映射与 0–100 域分。

## [S2] Design

### S2.1 范围

- 仅 Flutter App 本地量表：`apps/mobile/lib/core/survey/` + `features/analysis/survey_page.dart` + 单测。
- 不改 PHQ-9 / IBDQ / MiniQoL 计分；不改 `quality_surveys` 表结构（域分写入 `detail_json`）。
- 不做 PCS/MCS 常模、不做问卷版权合规声明升级（沿用「非诊断、仅供自管」文案）。

### S2.2 域映射契约（36 题索引，0-based）

当前 `sf36Questions` 顺序固定。映射表为**唯一真相**（纯函数）：

| 域 | 键 | 题索引 | 题数 | 含义 |
|----|----|--------|------|------|
| 一般健康 | `gh` | 0 | 1 | 总体健康自评 |
| 变化题 | — | 1 | — | **不计入任何域**（健康变化） |
| 生理功能 | `pf` | 2–9 | 8 | 活动受限 |
| 生理职能 | `rp` | 10, 11, 12, 34, 35 | 5 | 工作/计划因身体受限 |
| 躯体疼痛 | `bp` | 18, 19 | 2 | 疼痛程度与影响 |
| 精力 | `vt` | 20, 22, 25, 26 | 4 | 活力/精力/疲惫 |
| 社会功能 | `sf` | 16, 17, 23, 29, 31 | 5 | 社交与人际 |
| 情感职能 | `re` | 13, 14, 15, 28, 33 | 5 | 情绪导致的角色受限 |
| 精神健康 | `mh` | 21, 24, 27, 30, 32 | 5 | 平静/低落/专注/人际 |

- 覆盖题索引：0 + 2–36 共 35 题入域；索引 1 不入域。合计 35 题全入域无重复无遗漏（除变化题）。

### S2.3 计分契约

- 现有选项已统一「分越高越好」（0=很差 … 4=很好），**无需反向计分**。
- 域分：

```
domainScore = round( 100 * sum(itemValue) / (4 * itemCount) )   // 整数 0–100
```

- 域内题数 ≥1；`itemCount` 固定为映射表题数（本问卷无跳题，全部作答，无缺失处理）。
- **简化合计**保持不变：`total = sum(全部 36 题 0–4)`（含变化题，兼容旧历史）。
- 标准总览分（可选展示）：`stdAverage = round(mean(8 个域分))`，标签写「8 维均分」，**不称 PCS/MCS**。

### S2.4 存储（`detail_json` 扩展）

保存 SF36 时 `detail` 增：

```json
{
  "band": "...",
  "scores": [0..4 × 36],
  "labels": ["..."],
  "scoring": "v1-parallel",
  "domains": {"gh": 75, "pf": 90, "rp": 70, "bp": 62, "vt": 55, "sf": 80, "re": 75, "mh": 70},
  "stdAverage": 72
}
```

- 旧记录无 `domains` 字段：历史列表按「简化合计」展示，不回填、不迁移。
- 非 SF36 量表：不写 `domains`/`stdAverage`。

### S2.5 UI（`survey_page.dart`）

1. **实时预览区**（保存前）：在「当前合计 … 分 · band」下增加 8 维 chip 行（域中文名 + 0–100），以及「8 维均分」。
2. **保存 SnackBar**：`已保存：SF-36 · 简化 X 分 · 8 维均分 Y`。
3. **历史卡片**：有 `domains` 时展示均分与最弱 2 维（升序取 2，如 `较低：vt 55 · bp 62`）；无则维持现状。
4. **intro 文案**：去掉「简化 0–4 计分」独占表述，改为「同时输出标准 8 维 0–100 与简化合计，用于自管趋势；非授权正式量表，临床评估请用原版 SF-36」。
5. 域中文名：一般健康 / 生理功能 / 生理职能 / 躯体疼痛 / 精力 / 社会功能 / 情感职能 / 精神健康。

### S2.6 纯函数与测试边界

| 测试 | 覆盖 |
|------|------|
| `sf36_domain_score_test.dart` | 域映射：每题索引恰好入 0 或 1 个域；变化题不入域；域数=8 |
| 同上 | 边界：全 0→域 0；全 4→域 100；混合按公式 round |
| 同上 | `stdAverage` 为 8 域算术均四舍五入 |
| 同上 | 简化合计仍为 36 题之和 |

- 实现放 `apps/mobile/lib/core/survey/sf36_scoring.dart`（纯 Dart，无 Flutter 依赖）。
- 不在测试里复算生产公式副本以外的期望值来源；期望值手写数字。

### S2.7 错误与边界

- 域内题索引越界：函数 assert/抛 `ArgumentError`（测试钉住）。
- 旧历史无 domains：UI 不解析 domains，不崩。
- 导出 CSV/JSON：`detail_json` 原样透传（含 domains）；不改 `data_exporter` 结构。

## [S3] Out of Scope

- PCS/MCS 常模加权、缺失数据插补、正式 SF-36 授权文案。
- 改题干/选项档位、改 PHQ-9/IBDQ/MiniQoL。
- 服务端/domain-types、Web 端展示。
- 旧记录回填域分、趋势图 8 维曲线（后续可另立项）。

## Tasks

- [x] T1: `sf36_scoring.dart` 域映射 + `scoreDomain`/`scoreAll` 纯函数 — acceptance: `sf36_domain_score_test` 通过 (covers: S2.2, S2.3)
- [x] T2: `survey_page.dart` 预览/保存/历史展示 8 维 + intro 文案 — acceptance: 保存后 detail 含 domains/stdAverage；历史卡片显示均分与最弱 2 维 (covers: S2.4, S2.5; depends: T1)
- [x] T3: 回归：既有 survey 相关测试/analyze 无 error；worklist G7 标完成 — acceptance: `flutter test` 全绿、`flutter analyze` 无 error (covers: S2.6; depends: T1,T2)
