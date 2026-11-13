# PRD v1.3 代码事实核验卷（只读审计）

> 核验对象：`docs/IBD病程管理程序PRD-v1.2.md`（下称"PRD v1.2"）中与量表计分、检验/检查字段、注射排期、解析链路、缺失模块、预警规则、时间线、打卡、用药调整相关的表述。
> 核验范围：`apps/mobile/lib`、`apps/web/src`、`apps/miniapp/src`、`apps/doctor-web/src`、`services/api/src`、`services/parse-worker/app`、`packages/*`（必要时含迁移与测试）。
> 方法：逐条读取代码与 SQL/迁移，结论一律带 `file:line`；查不到的项写明搜索关键词与搜索范围，不做推测。
> 约束：**只读**。本卷未修改仓库任何代码/配置，未执行构建、测试或 git 操作；唯一写入文件即本文件。
> 时点：2026-11-02（以工作区当前文件为准）。

**图例**：支持｜部分｜不符｜查无（含义同任务书）。

---

## 一、结论速览

| # | 核验项 | 结论 | 证据（file:line） | 对 PRD v1.3 的影响 |
|---|--------|------|-------------------|--------------------|
| 1 | SF-36：36 题、统一 0–4、8 域、无反向、无 PCS/MCS | **部分** | `apps/mobile/lib/core/survey/survey_kit.dart:135-172,174-180`；`apps/mobile/lib/core/survey/sf36_scoring.dart:26-35,52-67,81-87` | 改状态＋补章节：必须写明"改写条目＋域映射非原版"，当前 PRD 只写"非原版权重/常模转换"过窄 |
| 2 | IBDQ：题数、选项、总分、band、是否等价 SIBDQ | **部分**（10 题属实；不等价 SIBDQ） | `survey_kit.dart:52-93,95-101,127-131`；`apps/mobile/lib/features/analysis/survey_page.dart:45` | 补章节：明确 1–5 分、10–50 分，**不得**与标准 SIBDQ 10–70 分对比 |
| 3 | 心理量表是否只有 PHQ-9，有无 PHQ-2/GAD-2 | **支持**（只有 PHQ-9） | `survey_kit.dart:3-49,119-125`；`apps/mobile/lib/features/analysis/analysis_tab.dart:141-147` | 无需改；若 v1.3 写 GAD-2 须标"未实现" |
| 4 | 检验套餐/指标清单、FCP refMax=200、可选指标覆盖 | **部分**（核心 7 项支持；可选指标多数查无） | `apps/mobile/lib/core/lab/lab_panels.dart:52-338`（FCP：`65-70`、`168-173`）；`kCoreLabNames:342-350` | 补章节：列"已内置/未内置"指标表；改状态若声称全覆盖 |
| 5 | 检验记录字段与存储（confidence/aliases/nameRaw/nameNorm/refMin/refMax/source；宽/长表） | **支持**（PRD 已如实）；confidence/aliases **查无** | `apps/mobile/lib/core/db/local_db.dart:131-152`；`services/api/src/database/entities/lab-result.entity.ts:26-48`、`lab-item.entity.ts:16-35`；`InitSchema:63-96` | 无需改；v1.3 若写 confidence/alias 属新需求 |
| 6 | 检查记录：score 自由文本、activity_score、诊断/对比入口 | **支持** | `local_db.dart:233-245`（score TEXT）；`apps/mobile/lib/features/analysis/clinical_pages.dart:40-72,146-159`；`activity_score` 全仓查无 | 无需改 |
| 7 | 仪表盘 Limberg/SES-CD 正则提取位置、IBUS-SAS 解析 | **支持**（Limberg/SES-CD）；**查无**（IBUS-SAS） | `apps/mobile/lib/core/activity/activity_service.dart:52-72`；调用：`features/home/activity_detail_page.dart:94-110,267-275` | 无需改，可补精确 file:line |
| 8 | 注射字段（App/service，plannedDate/actualDate/phase/weekNumber/next*） | **部分**（无 next*；App 阶段为伪标签、单间隔） | `local_db.dart:178-190`；`services/api/src/database/entities/injection.entity.ts:25-48`；`features/injection/injection_page.dart:119-130`；`injection.protocols.ts:29-104` | 改状态/补章节（服务端 4 协议库未接入 App） |
| 9 | complete.rescheduleDelay 是否顺延；下次预约字段；是否自动改写医嘱 | **不符**（顺延：服务端已实现；App 未实现）／下次预约**查无**／改写医嘱**查无** | `services/api/src/modules/injection/injection.service.ts:137-190`；`apps/mobile/lib/core/db/repositories.dart:192-200`；`ibd_api_client.dart:295-310`（无调用方） | 改状态（分端）、补章节；如需落库"下次预约"要改模型 |
| 10 | 待核对队列 / 已处理 PDF 清单 / 去重键 / 服务端日期优先级 | **查无**（队列/清单/去重）＋**支持**（日期优先级） | `parse-job.entity.ts:38`（`awaiting_review` 仅枚举）；`parse.service.ts:64-79,184-187,264-280`；`skill_engine.py:92-103`；`main.py:60-81` | 补章节：明确"无队列/无清单/无去重"；日期规则写清 |
| 11 | 模块存在性：疫苗/感染筛查、营养、就诊住院急诊、用药变更史、不良反应 | 疫苗**查无**；营养**部分/仅字段**；就诊住院**查无**（仅摘要生成）；用药变更史**部分**（服务端 API、无事件表；App 仅停用）；不良反应**仅字段/接口** | 见 §2.11 | 补章节（v1.3 需新增"未实现模块"清单） |
| 12 | 预警规则（flare、ai_rules）与指定阈值 | **部分** | `apps/mobile/lib/core/flare/flare_service.dart:33-107`；`apps/mobile/lib/core/ai/ai_rules.dart:144-216` | 补章节：列"有/无"规则表；LYM/CRP+FCP/体重/监测逾期均查无 |
| 13 | 时间线事件类型，疾病/不良反应事件 | **支持**（PRD 已标 ❌）；补充：无症状打卡事件 | `repositories.dart:506-584`；`features/analysis/timeline_page.dart:22-30` | 无需改；可补精确类型清单 |
| 14 | 每日打卡字段：体重/发热/夜间症状/粪便性状/黏液/紧迫感 | **部分**（性状/黏液/紧迫感有；体重/发热/夜间症状无） | `features/symptom/symptom_page.dart:593-1207`；`local_db.dart:192-204,298-348`；`symptom-diary.entity.ts:29-61` | 补章节；若 v1.3 要体重/发热须标"未实现" |
| 15 | 用药调整：服务端 adjust/pause/resume/stop/switch 与 App UI | **部分**（服务端全；App 仅停用/编辑=停旧建新） | `services/api/src/modules/medication/medication.controller.ts:56-113`；`medication.service.ts:116-181`；`features/medication/medication_page.dart:68-89`；`medication_edit_page.dart:213-215` | 改状态（App UI 缺口）、改模型（变更史需事件表） |

---

## 二、逐项核验

### 2.1 SF-36

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:499`：「- **SF-36**（通用生活质量量表）✅ 36 题；⚠️ 计分为简化 0–4 统一计分 + 自算 8 域 0–100 域分，非原版权重/常模转换（无 PCS/MCS）；另有域分趋势 ➕」
- `docs/IBD病程管理程序PRD-v1.2.md:1033`：「| 11 | §2.7.4 | SF-36 标准量表 | 简化 0–4 计分 + 自算 8 域分（非原版权重/常模） |」

**代码事实**
1. 题目数：`sf36Questions` 共 **36** 条（`survey_kit.dart:135-172`，程序计数 36）。
2. 选项：**统一 5 档 0–4、方向统一为"分越高越好"**（`survey_kit.dart:174-180`），因此代码**不做反向计分**（`sf36_scoring.dart:3` 注释明示"选项已统一…无需反向计分"；全仓无 reverse/反向计分实现）。
3. 域映射（0-based 索引，`sf36_scoring.dart:26-35`）：`gh:[0]`、`pf:[2..9]`、`rp:[10,11,12,34,35]`、`bp:[18,19]`、`vt:[20,22,25,26]`、`sf:[16,17,23,29,31]`、`re:[13,14,15,28,33]`、`mh:[21,24,27,30,32]`。即每域条目数为 **GH1 / PF8 / RP5 / BP2 / VT4 / SF5 / RE5 / MH5**；映射总计 35 题，另 1 题为"与一年前相比"变化题（`changeItemIndex=1`，`sf36_scoring.dart:22-23`），**不入任何域**。
4. 域分公式：**`round(100 × Σitem / (4 × n_域))`**，值域 0–100（`sf36_scoring.dart:52-67`，公式在 `:66`）。这是"等权线性 0–100 变换"，不是原版 SF-36 的常模（norm-based）计分。
5. 简化合计：**36 题全部求和（含变化题）**，0–144（`sf36_scoring.dart:81-87`）；band：≥110 较好、≥72 一般、<72 较差（`survey_kit.dart:182-186`）。
6. 8 维"标准均分"：**8 个域分的算术平均值**（`sf36_scoring.dart:69-79`；`:44` 注释"（非 PCS/MCS）"）。应用源码（apps/*、services/api、parse-worker/app、packages）中 `PCS|MCS` 仅此注释，**无 PCS/MCS 计算**。
7. 条目文字：为中文改写/通俗化条目（如"总体健康状况自评""剧烈活动是否受限"），**不是原版 SF-36 中文版原句**；且原版各题选项数不同（3/5/6 档、是否题），此处被统一为 5 档。
8. 结果落库：`quality_surveys(total, detail_json)`，域分写入 `detail.domains` + `detail.stdAverage`（`survey_page.dart:52-76`；表结构 `local_db.dart:267-281`），趋势从 JSON 解析（`sf36_trend.dart:21-57`）。

**关键代码片段**（域映射，`sf36_scoring.dart:27-34`）
```dart
    'gh': [0],
    'pf': [2, 3, 4, 5, 6, 7, 8, 9],
    'rp': [10, 11, 12, 34, 35],
    'bp': [18, 19],
    'vt': [20, 22, 25, 26],
    'sf': [16, 17, 23, 29, 31],
    're': [13, 14, 15, 28, 33],
    'mh': [21, 24, 27, 30, 32],
```

**对"重点问题"的逐答**
- 36 题是否为原版条目？**否**——语义近似、文字为改写，且题目顺序/条目构成与原版不完全对应（如需逐题对照，可另附对照表）。
- 选项是否统一"分越高越好"0–4？**是**（`survey_kit.dart:174-180`）。
- 域映射是否原版（PF10/RP4/BP2/GH5/VT4/SF2/RE3/MH5）？**否**：实际 GH1/PF8/RP5/BP2/VT4/SF5/RE5/MH5，PF 少 2 题、GH 少 4 题、RP 多 1、SF 多 3、RE 多 2。
- 有无反向计分？**无**（统一方向后不需要；但这意味着不是原版计分链路）。
- 有无 PCS/MCS？**无**（仅 8 域均分）。
- 域分公式？`round(100*sum/(4*n))`。

**结论：部分**。PRD v1.2 的"36 题、简化 0–4、自算 8 域、无 PCS/MCS"在**题数与计分方式**上属实；但"8 域"会让人误解为原版 8 域，实际**域映射条目数与原版不一致、题目非原版**。v1.3 应改为"自定义 8 维（非原版映射）"，并补域条目数表；若产品要"标准 SF-36"，属新需求（见第四节模型建议）。

---

### 2.2 IBDQ

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:500`：「- **IBDQ**（IBD专用生活质量量表）⚠️ 简版 10 题」

**代码事实**
1. 题目数 **10**（`survey_kit.dart:52-93`，程序计数 10）。
2. 选项 **5 档、分值 1–5**（`survey_kit.dart:95-101`：1 很差/总是 … 5 很好/几乎没有）。
3. 总分 = 各题求和，**10–50**（`survey_page.dart:45`；`SurveyKit.maxScore('IBDQ')=4`，`survey_kit.dart:263`）。
4. band：**≥40 较好、≥30 一般、<30 较差**（`survey_kit.dart:127-131`），无文献依据说明。
5. 题目内容为自编简版（胃肠不适频率、精力、担心发作、日常影响、食欲、睡眠、腹痛、社交、治疗信心、整体满意），**不是标准 SIBDQ 的 10 条原文条目**。

**关键代码片段**（`survey_kit.dart:95-101`）
```dart
  static const ibdqOptions = [
    SurveyOption(1, '很差 / 总是', '几乎每天都不舒服或受影响'),
    SurveyOption(2, '较差 / 常常', '一周大半时间如此'),
    SurveyOption(3, '一般 / 有时', '有好有坏'),
    SurveyOption(4, '较好 / 偶尔', '多数时候还行'),
    SurveyOption(5, '很好 / 几乎没有', '几乎不受影响'),
  ];
```

**结论：部分**。题数 10 与 PRD 一致；但**选项 1–5、总分 10–50**，与标准 SIBDQ（10 题、1–7 分、10–70）**不等价**，因此不能与文献 SIBDQ 分值/阈值互换。v1.3 需补"非标准 SIBDQ、1–5 分、10–50、band 为产品自定义"。

---

### 2.3 心理量表（PHQ-9 / PHQ-2 / GAD-2）

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:501`：「- **PHQ-9**（心理健康筛查）✅」
- `docs/IBD病程管理程序PRD-v1.2.md:508`：「- 识别心理健康风险（PHQ-9 分级）✅」

**代码事实**
1. 量表注册仅 4 种：`PHQ9 / IBDQ / SF36 / MiniQoL`（`analysis_tab.dart:141-147`；`survey_kit.dart:207-231`）。
2. PHQ-9：9 题、选项 0–3（`survey_kit.dart:4-49`），band 0–4/5–9/10–14/15–19/≥20（`survey_kit.dart:119-125`）。
3. **PHQ-2 / GAD-2 / GAD-7 全仓查无**：在 `apps/mobile/lib`、`apps/web/src`、`apps/miniapp/src`、`apps/doctor-web/src`、`services/api/src`、`services/parse-worker/app`、`packages` 搜索 `GAD\|GAD-2\|GAD-7\|PHQ-2\|PHQ2\|gad2\|焦虑`，仅命中 `repositories.dart:682` 的注释"生活质量/心理量表"，无任何实现。
4. MiniQoL 是 5 题生活评分（`survey_kit.dart:103-117`），不是心理专项量表。

**关键代码片段**（`survey_kit.dart:43-49`）
```dart
  /// PHQ-9 选项：0–3
  static const phq9Options = [
    SurveyOption(0, '完全没有', '几乎没有这种情况'),
    SurveyOption(1, '有几天', '偶尔出现，不是天天'),
    SurveyOption(2, '一半以上天数', '差不多隔天或更常'),
    SurveyOption(3, '几乎每天', '天天都有'),
  ];
```

**结论：支持**。PRD 只声称 PHQ-9，代码一致；**没有 PHQ-2/GAD-2**。v1.3 无需改，若新增 GAD-2 需标"未实现"。

---

### 2.4 检验套餐、指标清单与 FCP 参考范围

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:205`：「**IBD核心指标面板**（✅ 已实现，7 项核心指标）：」
- `docs/IBD病程管理程序PRD-v1.2.md:207-215`：CRP<5.0、ESR<15、粪便钙卫蛋白<200、淋巴细胞 1.1–3.2、白蛋白 40–55、血红蛋白 130–175、尿酸 208–428。
- `docs/IBD病程管理程序PRD-v1.2.md:211`：「| 粪便钙卫蛋白 | <200 μg/g | **肠道炎症金标准**，最敏感 |」

**代码事实**
1. `lab_panels.dart` 共 **6 个套餐**（`kLabPanels`，`lab_panels.dart:52-338`）：
   - `ibd_core`（IBD 核心，7 项，`:53-100`）
   - `cbc`（血常规，6 项，`:101-149`）
   - `inflammation`（炎症指标，5 项，`:150-181`）
   - `liver`（肝功能，7 项，`:182-233`）
   - `kidney_metabolic`（肾功能代谢，7 项，`:234-288`）
   - `nutrition_anemia`（营养贫血，6 项，`:289-337`）
   去重后共 **29 个规范化指标名**。
2. FCP 默认参考范围 **`refMax: 200`（单位 μg/g）**，出现在两处：`ibd_core` 的 `lab_panels.dart:65-70`（`refMax: 200` 在第 **69** 行）；`inflammation` 的 `lab_panels.dart:168-173`（`refMax: 200` 在第 **172** 行）。
3. 核心 7 项与 `kCoreLabNames` 同源（`lab_panels.dart:342-350`；PRD §2.1.3 的 7 项全部覆盖）。
4. 可选指标覆盖（在 `lab_panels.dart` 内逐名检索）：

| 指标 | 是否内置 | 证据 |
|------|:---:|------|
| TG（甘油三酯） | ❌ 查无 | — |
| TC（总胆固醇） | ❌ 查无 | — |
| LDL-C | ❌ 查无 | — |
| HDL-C | ❌ 查无 | — |
| CK（肌酸激酶） | ❌ 查无 | — |
| BUN（尿素氮） | ✅ | `lab_panels.dart:253-259` |
| FOB（便隐血） | ❌ 查无 | — |
| 血清铁蛋白 | ✅ | `lab_panels.dart:301-307` |
| VD（25-OH 维生素 D） | ❌ 查无 | — |
| 维生素 B12 | ✅ | `lab_panels.dart:308-314` |
| 叶酸 | ✅ | `lab_panels.dart:315-321` |
| 钙 | ✅ | `lab_panels.dart:280-286` |
| 磷 | ❌ 查无 | — |
| 镁 | ❌ 查无 | — |
| 前白蛋白 | ✅ | `lab_panels.dart:329-335` |

5. 补充：App 录入页支持**自定义行**（`lab_entry_page.dart:782`「添加自定义一项」；保存逻辑 `:461-476`），因此任意名称的指标可手工录入；但自定义行只有名称/数值/单位，**无参考范围输入**（`:470-475`），故不会产生 ↑/↓ flag。

**关键代码片段**（FCP，`lab_panels.dart:65-70`）
```dart
      LabItemSpec(
        nameNorm: '粪便钙卫蛋白',
        nameRaw: 'FC',
        unit: 'μg/g',
        refMax: 200,
      ),
```

**结论：部分**。PRD 声称的"7 项核心指标"**支持**；PRD 未声称覆盖 TG/TC/LDL-C/HDL-C/CK/FOB/VD/磷/镁 等可选指标，故**不算 PRD 失实**，但 v1.3 若写"可选指标覆盖"必须标注"未内置（仅可自定义录入、无参考范围）"。

---

### 2.5 检验记录字段与存储模型（App + 服务端 + 迁移）

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:698`：「| LabResult | ✅ `source` 三值 `skill｜ai｜manual` 如实写入（T2；旧数据不回填）；➕ deviceId、HLC 混合逻辑钟字段 |」
- `docs/IBD病程管理程序PRD-v1.2.md:699`：「| LabItem | ⚠️ name 拆 `nameNorm/nameRaw`、referenceRange 拆 `refMin/refMax` |」
- `docs/IBD病程管理程序PRD-v1.2.md:587-596`：LabResult 目标模型（date/hospital/items/name/value/unit/referenceRange/flag/source）。

**代码事实（App 本地 SQLCipher，`local_db.dart`）**
- 头表 `labs`：`id, date, hospital, source DEFAULT 'manual', created_at`（`:131-139`）。
- 明细表 `lab_items`：`id, lab_id, name_norm, name_raw, value, unit, ref_min, ref_max, flag`（`:140-152`）。
- **存储形态：头表 + 明细长表（一行一个指标），不是宽表**。
- `confidence`：**查无**（全仓 `*.dart` 搜 `confidence\|置信度` 0 命中）。
- `aliases`：**查无**（仅 `ParseSkill` 规则里有 `alias`，解析时被折成 `nameRaw`：`lab_parse_mapper.dart:7-10`；不落库为 aliases）。
- `source` 是**记录级**（labs.source），不是指标级。

**代码事实（服务端 TypeORM 实体 + 迁移）**
- `lab_results`：`id, patientId, date, hospital, source('skill'|'ai'|'manual'), deviceId, hlcWallMs, hlcCounter, items, createdAt`（`lab-result.entity.ts:16-51`）。
- `lab_items`：`id, labResultId, nameNorm, nameRaw, value, unit, refMin, refMax, flag`（`lab-item.entity.ts:16-35`）。
- 迁移建表：`services/api/src/database/migrations/1726200000000-InitSchema.ts:63-96`（`lab_results` 63-78；`lab_items` 81-96）；后续无 lab 两表结构变更。解析任务字段另见 `1726400000000-AddParseSkills.ts:43-55`（reportType/reportDate/confirmedItems/confirmedAt/labResultId）、`1726900000000-AddParseSourceDeleted.ts:9`、`1727600000000-AddParseJobEngine.ts:13`。

**关键代码片段**（`local_db.dart:141-151`）
```dart
      CREATE TABLE IF NOT EXISTS lab_items (
        id TEXT PRIMARY KEY,
        lab_id TEXT NOT NULL REFERENCES labs(id) ON DELETE CASCADE,
        name_norm TEXT NOT NULL,
        name_raw TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT,
        ref_min REAL,
        ref_max REAL,
```

**结论：支持**（PRD 对 `nameNorm/nameRaw/refMin/refMax/source` 的描述与代码一致；存储为长表）。**`confidence`/`aliases` 查无**。v1.3 无需改；若写"置信度/别名"需先建字段（见第四节模型建议）。

---

### 2.6 检查记录：score 自由文本、activity_score、诊断/对比入口

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:233-238`：「**结构化存储**（⚠️ 部分实现）：- 检查日期、检查类型、检查部位 ✅（录入表单另有"所见/评分"）- 关键发现（文字摘要）✅ - 诊断结论、与历史检查的对比（如"较前好转"）⚠️ 数据列已建，录入入口缺失 - 评分系统记录（如SES-CD、Limberg、IBUS-SAS）⚠️ 评分自由文本；仪表盘已按正则提取 **Limberg / SES-CD** 趋势；IBUS-SAS 未支持 - 影像/报告附件 ❌ 未实现」（`:234-238`）

**代码事实**
1. App 本地 `exams` 表：`id, date, type, body_part, findings, diagnosis, score, comparison, created_at`（`local_db.dart:233-245`；`score TEXT` 在 `:241`）。
2. 录入表单仅 5 个输入：日期/类型/部位/所见/评分（`clinical_pages.dart:50-54`），**无 diagnosis、无 comparison、无附件**（保存调用 `:65-72`）。
3. **无 `activity_score` / 评分类型字段**：全仓 `*.dart|*.ts` 搜 `activity_score\|activityScore` 0 命中。
4. 列表仅展示日期/所见/评分文本（`clinical_pages.dart:146-159`）。
5. 服务端**无 Exam/Surgery 实体/表/API**（`services/api/src/modules` 无 exam/surgery 目录；`database/entities` 22 个实体中无 exam/surgery；迁移 `CREATE TABLE` 清单无这两张表）。

**关键代码片段**（`clinical_pages.dart:50-54`）
```dart
              TextField(controller: date, decoration: const InputDecoration(labelText: '日期')),
              TextField(controller: type, decoration: const InputDecoration(labelText: '类型')),
              TextField(controller: part, decoration: const InputDecoration(labelText: '部位')),
              TextField(controller: findings, decoration: const InputDecoration(labelText: '所见')),
              TextField(controller: score, decoration: const InputDecoration(labelText: '评分（可选）')),
```

**结论：支持**。score 确为自由文本；无 activity_score/评分类型；诊断/对比有列无入口；服务端无实体——与 PRD 表述一致。

---

### 2.7 仪表盘 Limberg / SES-CD 正则提取与 IBUS-SAS

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:237`：「- 评分系统记录（如SES-CD、Limberg、IBUS-SAS）⚠️ 评分自由文本；仪表盘已按正则提取 **Limberg / SES-CD** 趋势；IBUS-SAS 未支持」
- `docs/IBD病程管理程序PRD-v1.2.md:416-417`：「- Limberg分级趋势（超声）✅ - SES-CD评分趋势（内镜）✅」

**代码事实**
1. 正则定义在 `apps/mobile/lib/core/activity/activity_service.dart`：
   - `extractLimberg`：`RegExp(r'Limberg\s*[：:]?\s*([0-4]|[IViv]{1,4})', caseSensitive: false)`（`:52-62`）。
   - `extractSesCd`：`RegExp(r'SES\s*-\s*CD\s*[：:]?\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false)`（`:64-72`）。
2. 调用位置：`features/home/activity_detail_page.dart:94-110`（`_limbergSeries` / `_sesSeries` 读 `exams.score` + `exams.findings`），渲染在 `:267-275`（"Limberg 分级趋势（超声）"/"SES-CD 评分趋势（内镜）"）。
3. 首页只是活动度卡（三联灯/倒计时/用药摘要）并跳转详情页（`dashboard_tab.dart:49-63,152-173`），**趋势提取发生在详情页**，不在首页卡内。
4. **IBUS-SAS 无任何解析**：全仓搜 `IBUS\|ibus` 仅命中文档（`docs/*`），代码 0 命中；`exam` 的 score 提示文案也不含 IBUS（`activity_detail_page.dart:268,274` 只提示 Limberg/SES-CD）。

**关键代码片段**（`activity_service.dart:54-58`）
```dart
String? extractLimberg(String? score, String? findings) {
  final text = '${score ?? ''} ${findings ?? ''}';
  final m = RegExp(
    r'Limberg\s*[：:]?\s*([0-4]|[IViv]{1,4})',
    caseSensitive: false,
  ).firstMatch(text);
```

**结论：支持（Limberg/SES-CD）／查无（IBUS-SAS）**。PRD 表述正确；建议 v1.3 把"仪表盘"精确为"活动度详情页"，并给出 `activity_service.dart:52-72` 证据。

---

### 2.8 注射字段（App vs 服务端）

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:288-293`：「**注射排期功能**（⚠️ 部分实现）：- 根据药物方案自动生成注射日历 ✅（起始日 + 固定间隔 + 月历预览）- 区分诱导期和维持期的不同频率 ⚠️ **未实装**：App 端按单一间隔生成、阶段为伪标签（诱导/维持协议表已定义未接入）；服务端存有 4 种生物制剂诱导/维持协议库 - 注射前X天提醒（可配置，默认3天）✅ … - 记录每次实际注射日期（可能与计划有偏差）✅（"今天已打"）- 延迟注射后自动调整后续排期 ❌ 未实现（记录实际日期后，后续计划日期不顺延）」
- `docs/IBD病程管理程序PRD-v1.2.md:621-629`：Injection 目标模型（drug/plannedDate/actualDate/phase/dose/route/weekNumber/notes）。
- `docs/IBD病程管理程序PRD-v1.2.md:702`：「| Injection | ✅ 与目标模型一致；➕ 服务端排期协议库与 schedule/upcoming/complete API |」

**代码事实（App 本地）**
- 表 `injections`：`id, drug, planned_date, actual_date, phase, dose, route, week_number, notes`（`local_db.dart:178-190`）——与目标模型字段一致，**无 `next*` 字段**。
- 生成逻辑：单一间隔 + 起始日生成 24 次（`injection_page.dart:97-130`；`buildIntervalDates` 在 `drug_catalog.dart:143-154`）。
- **phase 为伪标签**：`'phase': i == 0 && dates.length > 1 ? 'induction' : 'maintenance'`（`injection_page.dart:124`），即只有第 1 针标 induction。
- App 的协议表 `protocols.dart` 只有 2 个协议（skyrizi/humira，`:40-67`），且 `kProtocols`/`buildSchedule` **全仓无调用方**（死代码）。
- 药品目录 8 类（`drug_catalog.dart:34-130`：阿达木、英夫利西、乌司奴、利生奇珠、维得利珠、戈利木、赛妥珠、乌帕替尼），与 PRD"8 种"一致；乌帕替尼按口服处理（`injection_page.dart:126`）。

**代码事实（服务端）**
- 实体 `injections`：`id, patientId, drug, plannedDate, actualDate, phase('induction'|'maintenance'), dose, route('sc'|'iv'), weekNumber, notes, createdAt, updatedAt`（`injection.entity.ts:25-53`）——**无 `next*` 字段**。
- 协议库 **4 种**：skyrizi/humira/stelara/entyvio（`services/api/src/modules/injection/injection.protocols.ts:29-104`；`listProtocols:97-104`）。
- API：`GET /injections/protocols`、`GET /injections`、`GET /injections/upcoming`、`POST /injections/schedule`、`POST /injections`、`POST /injections/:id/complete`（`injection.controller.ts:20-63`）。

**关键代码片段**（App 伪 phase，`injection_page.dart:120-128`）
```dart
        for (var i = 0; i < dates.length; i++)
          {
            'drug': drugLabel,
            'plannedDate': isoDate(dates[i]),
            'phase': i == 0 && dates.length > 1 ? 'induction' : 'maintenance',
            'dose': _unit == 'weeks' && interval >= 6 ? '维持' : '按方案',
            'route': cat.key == 'upadacitinib' ? 'oral' : 'sc',
            'weekNumber': i,
            'notes': '${cat.mechanism} · 每 $interval $_unit',
          },
```

**结论：部分**。字段与目标模型基本一致（无 `next*`）；"App 单间隔 + 伪 phase"与 PRD 一致；"服务端有 4 种协议库"一致，但**协议库未接入 App**（App 只用药品目录的默认间隔）。`phase` 在 App 端几乎不可用（生成时只有第 1 针是 induction），v1.3 若要写"诱导/维持"必须分端标注。

---

### 2.9 延迟顺延、下次预约、自动改写医嘱

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:293`：「- 延迟注射后自动调整后续排期 ❌ 未实现（记录实际日期后，后续计划日期不顺延）」

**代码事实（服务端：已实现顺延）**
`InjectionService.complete()`（`injection.service.ts:137-190`）：
1. 计算 `delayDays = max(0, actualDate - plannedDate)`（`:152-161`）。
2. 先写 `actualDate`（`:163-166`）。
3. 若 `input.rescheduleDelay !== false && delayDays > 0`（**默认即为 true**）：取同患者+同药、`actualDate IS NULL` 的所有未完成计划，对 `plannedDate > 当前针 plannedDate` 的每一行 **+delayDays 天**（`:168-187`），返回 `{injection, delayDays, shifted}`（`:189`）。
4. 顺延只动 `injections.plannedDate`，**不写 medications**，也**不写任何"医嘱"表**（全文件无 medications 依赖，`:1-191`）。

**代码事实（App：未实现）**
- App 的"今天已打"调用本地 `InjectionRepository.complete`，只更新 `actual_date`（`repositories.dart:192-200`）；**不顺延后续 planned_date**。
- App 有 `IbdApiClient.completeInjection(... rescheduleDelay = true)`（`ibd_api_client.dart:295-310`），但**全仓无调用方**（`features/` 内搜 `completeInjection|generateSchedule|listInjections` 0 命中）；`injection_page.dart:159-162` 只调本地 repo。
- SWE 说明：服务端 `complete` 还支持 `POST /injections/schedule` 生成协议排期，但 App 未调用（`injection_page.dart` 本地生成）。

**其他两个问题**
- **"下次预约日期"字段：查无**。全仓 `下次预约|预约日期` 0 命中；"下一次注射"是运行时从最早未完成 `planned_date` 派生：
  - `daysUntilInjection`（`activity_service.dart:41-50`）；
  - `activity_detail_page.dart:112-118`（排序取最早 pending）；
  - `dashboard_tab.dart:80` 显示"逾期 N 天"，`activity_detail_page.dart:222` 显示"已逾期 N 天"。
- **完成后是否会自动改写医嘱：查无**。服务端 `complete` 只更新 injections；仓库中无"注射完成→改 medication"的调用链；全仓 `医嘱` 仅出现在免责/提醒文案（如 `core/ui/disclaimer.dart:10`、`reminder_copy.dart:19-24`），无"医嘱优先/回写"逻辑。

**关键代码片段**（服务端顺延，`injection.service.ts:169-184`）
```ts
    let shifted = 0;
    if (input.rescheduleDelay !== false && delayDays > 0) {
      const futures = await this.injections.find({
        where: {
          patientId: patient.id,
          drug: job.drug,
          actualDate: null as never,
        },
      });
      for (const f of futures) {
        if (f.plannedDate <= job.plannedDate) continue;
        const d = new Date(`${f.plannedDate}T00:00:00Z`);
        d.setUTCDate(d.getUTCDate() + delayDays);
```

**结论：不符（PRD 已过时）**。结论应分端写：
- 服务端：**已实现**延迟顺延（默认 `rescheduleDelay=true`；可传 `false` 关闭）。
- App：**未实现**（本地只记实际日期；未接服务端 complete）。
- "下次预约日期"字段：**查无**（由最早 pending planned_date 派生）。
- 自动改写医嘱：**查无**。

v1.3 应把 `:293` 改为「⚠️ 服务端 complete 已支持顺延（`:168-187`）；App 端未接入、不顺延」。另建议补审计：`delayDays/shifted` 只在响应中返回，**未落库**。

---

### 2.10 解析链路：待核对队列、已处理 PDF 清单、去重、日期优先级

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:49-51`：「**功能描述**：支持上传医院检验/检查报告PDF，通过**AI智能识别**…」；实现状态：「双引擎解析已实现，但**引擎运行在服务端**（`services/parse-worker`：Skill 模板命中 → 未命中回落 LLM/Vision 解析）；App/PC Web 端负责上传、确认与"用完即删"。Skill 模板的 `check_fn`、跨行（multiline）提取…均**未实现**」。
- `docs/IBD病程管理程序PRD-v1.2.md:93-96`：「# 日期提取规则（✅ 已实现 primary/fallback 双规则）date_extraction: primary: '(\d{8})G\d+' fallback: '采集日期:\s*(\d{4})/(\d{1,2})/(\d{1,2})'」
- `docs/IBD病程管理程序PRD-v1.2.md:176`：「> ⚠️ 上表速度/准确率为**设计目标**，当前无实测统计…」
- `docs/IBD病程管理程序PRD-v1.2.md:188`：「- 数据来源标记（Skill解析/AI解析/手动录入）✅ 如实写入（T2：confirm 按真实引擎、App 三档；旧数据不回填）」

**代码事实**

**(a) 待核对队列：查无（只有录入页内联核对）**
- `parse_jobs.status` 类型里有 `awaiting_review`（`parse-job.entity.ts:38`），但**全仓无任何赋值/读取**（搜 `awaiting_review` 仅此 1 处）。
- 解析失败仅把 status 置 `failed` + error（`parse.service.ts:282-286`），无重试队列/人工核对队列/审核页。
- 用户侧"核对"发生在录入页内联：解析结果填入可编辑行 + 提示"已解析 N 项，请核对后保存到本机"（`lab_entry_page.dart:147-178`，提示在 `:175`）；失败时可改用套餐手填（`:174`）。

**(b) 已处理 PDF 清单：查无（仅服务端有列表接口，无客户端消费）**
- 服务端 `GET /parse/jobs`（`parse.controller.ts:24-27`）返回该患者所有 job（`parse.service.ts:168-174`）。
- 但 App 无 `listParseJobs` 方法/页面：`ibd_api_client.dart` 只有 `enqueueParse/getParseJob/deleteParseSource`（`:212-247`）；`parse_upload_page.dart` 是 13 行跳转壳（`:6-12`）；Web 端 `ParseBatch.tsx` 的任务列表只是内存态（`:4-11,21`），刷新即失。全仓搜 `listParseJobs` 0 命中。
- 无持久化"已处理 PDF 清单"（无 file hash / objectKey 唯一记录 / 处理时间列表的客户端展示）。

**(c) 去重键：查无**
- 服务端 enqueue **不检查重复**：每次 `POST /parse/jobs` 都新建 job（`parse.service.ts:64-79`；`jobs.save(...)`）。
- confirm 写 lab 时**不检查**同患者/同日期/同项目是否已存在：`labs.create()` 直接保存（`lab.service.ts:44-68`）；App 本地 `LabRepository.insert()` 也无存在性判断（`repositories.dart:12-48`）。
- Web 批量解析对每个文件直接 `confirmParse`（`ParseBatch.tsx:94-105`），无"日期+类型"或"日期+项目"去重。
- 全仓搜 `dedupe\|duplicate\|去重\|重复` 仅命中：食物标签去重（`food_nutrition.dart:98`）、打卡同步细表替换（`repositories.dart:226`）、迁移重入（`local_db.dart:106,299`）——**均与 PDF/检验去重无关**。

**(d) 服务端日期提取优先级：存在，链路如下**
1. Skill 模板：`date_extraction.primary` → `fallback`（`skill_engine.py:92-103`；样例键顺序在 `:94`），命中即 break。
2. Skill 未命中 → AI 解析，要求模型返回 `date:"YYYY-MM-DD或null"`（`ai_engine.py:23-26`；`main.py:60-81` 的 pipeline 顺序：库内 Skill → 本地样例 Skill → AI）。
3. Worker 返回日期后，服务端 `markCompleted` 仅接受严格 `YYYY-MM-DD`，否则保留原 `job.reportDate`（`parse.service.ts:264-280`，`:267-269`）。
4. confirm 最终日期：**`input.date`（用户确认时传入） > `job.reportDate`（解析结果） > 当天**（`parse.service.ts:184-187`）。
5. **App 端不使用解析日期**：录入页日期默认当天（`lab_entry_page.dart:98,120-125`），云端解析只取 `done.items`（`:333-348,356-393`），保存时用输入框日期（`:490-492`）。因此 App 的"解析入库"实际日期 = 用户手填（默认今天），不是报告日期。

**关键代码片段**（confirm 日期优先级，`parse.service.ts:184-187`）
```ts
    const date =
      input.date ||
      job.reportDate ||
      new Date().toISOString().slice(0, 10);
```

**结论：查无（队列/清单/去重键存在性）＋ 支持（日期优先级）**。v1.3 若描述"待核对队列""已处理 PDF 清单""自动去重"，均与代码不符（当前为：服务端 API 有 job 列表但无客户端；核对是页内联；无任何去重）。日期规则可如实写入，但要补"App 端不采用报告日期，默认今天，需用户手改"。

---

### 2.11 模块存在性（疫苗/感染筛查、营养、就诊/住院/急诊、用药变更史、不良反应）

**PRD v1.2 原句**
- PRD v1.2 **没有**"疫苗/感染筛查""就诊/住院/急诊记录""体重/BMI/特殊饮食阶段"章节；仅有：
  - `docs/IBD病程管理程序PRD-v1.2.md:952-956`：§5.5 饮食管理（食谱/食物-症状关联/营养摄入粗记）。
  - `docs/IBD病程管理程序PRD-v1.2.md:358-382`：§2.4.2 就诊摘要（生成文本，不是就诊记录）。
  - `docs/IBD病程管理程序PRD-v1.2.md:263-267`：§2.2.2 用药历史（切换链/停药原因/副作用/剂量调整）。

**代码事实（按"页面/表/接口"三查）**

| 模块 | 页面 | 表/实体 | 接口 | 判定 |
|------|------|---------|------|------|
| 疫苗/感染筛查 | ❌ 无（`features/` 9 个目录无相关页；5 个底部 Tab 见 `shell_page.dart:35-41`） | ❌ 无（21 个服务端实体、24 张迁移表均无） | ❌ 无（13 个 API 模块目录无） | **查无** |
| 营养：体重/BMI | ❌ 无体重/身高/BMI 任何字段（App 打卡表、服务端 symptom_diaries、food_logs 均无；全仓 `体重` 仅命中 `injection.protocols.ts:65` 的剂量文案"体重按说明书"；`BMI` 0 命中） | ❌ 无 | ❌ 无 | **查无** |
| 营养：特殊饮食阶段 | ❌ 无阶段模型/页面 | ❌ 无 | ❌ 无 | **查无**（仅有食物词典文案"发作期常见低渣思路"，`food_dictionary.dart:63`） |
| 营养：热量/蛋白粗记 | ✅ 食物与排便页（`food_stool_page.dart:213` 汇总） | ✅ 本地 `food_logs.calories/protein_g`（`local_db.dart:364-368`） | ❌ 无服务端接口（本地表，服务端无实体） | **仅字段/仅本地** |
| 就诊/住院/急诊记录 | ❌ 无记录页（只有 `VisitSummaryPage` 生成摘要，`clinical_pages.dart:366-445`） | ❌ 无（搜 `住院\|hospitaliz\|admission` 仅命中脱敏正则 `skill-community.scrub.ts:24`；`急诊` 仅命中 `flare_service.dart:59` 文案） | ❌ 无（医生端只有 `visit-summary.ts` 文本组装） | **查无**（就诊摘要≠就诊记录） |
| 用药变更史 | ⚠️ App 只有"停用"（`medication_page.dart:68-89`）+ 编辑=停旧建新（`medication_edit_page.dart:213-215`） | ✅ 服务端 `medications`（状态/起止/reason，`medication.entity.ts`）；❌ 无变更事件表（无 eventType） | ✅ adjust/pause/resume/stop/switch/adverse-events（`medication.controller.ts:56-113`） | **部分**（服务端 API 齐；无事件模型；App UI 缺 pause/resume/switch/adjust） |
| 不良反应 | ❌ App 无"按药物记录的不良反应事件"UI（`features/` 全目录搜 `adverse` 0 命中；仅药物评价页有主观副作用评分：`drug_review_page.dart:229-241,322-323`，与 `adverse_events` 表/接口不连通） | ✅ 本地 `adverse_events` 表（`local_db.dart:168-177`）+ 服务端实体/表（`1726500000000-AddAdverseEvents.ts:8`） | ✅ `POST/GET /medications/:id/adverse-events`（`medication.controller.ts:101-113`） | **仅字段/接口，无 UI** |
| 疾病事件（确诊/复发/并发症） | ❌ 无 | ❌ 无（无 disease event 表） | ❌ 无 | **查无** |
| 随访/复诊 | ❌ 无随访记录（PRD 的"复查提醒"是本地通知条目，见 `reminder_prefs.dart:70-95`） | ❌ 无 | ⚠️ 服务端有 reminder_rules（通用规则表，`InitSchema:184`），非随访记录 | **查无（记录层面）** |

**关键代码片段**（App 只有 5 个底部入口，`shell_page.dart:35-41`）
```dart
    final pages = [
      DashboardTab(onOpen: _goTab),
      const SymptomPage(embedded: true),
      const InjectionPage(embedded: true),
      const AnalysisTab(),
      SettingsPage(embedded: true, syncOn: identity.syncOptIn),
    ];
```

**结论：混合**。疫苗/感染筛查、体重/BMI/特殊饮食阶段、就诊/住院/急诊记录、疾病事件：**查无**；营养仅"热量/蛋白粗记"（本地）；用药变更史**服务端接口有、无事件模型、App UI 不全**；不良反应**仅字段/接口、无 UI、不进时间线**。v1.3 若计划纳入这些模块，必须新写"未实现"章节，不能沿用"已实现"语境。

---

### 2.12 预警规则现状（flare_service / ai_rules）

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:480`：「> **实现状态（2026-10-26）⚠️**：三级预警已实现，但判定为**本地规则引擎**（阈值+连续恶化），非 AI/ML；不参考历史发作前模式；🔴 级缺"发热>38°C"条件（无体温字段）；预警摘要无外发入口；评估结果**不持久化**…」
- `docs/IBD病程管理程序PRD-v1.2.md:482-488`：三级预警表（🟢正常/🟡关注"症状连续3天加重，或排便次数突增"/🔴警告"便血、剧烈腹痛"）。
- `docs/IBD病程管理程序PRD-v1.2.md:922`：「- 异常指标预警（如"钙卫蛋白连续两次升高，建议就医"）⚠️ 规则版：连续升高、便血连续、排便突增等提示」

**代码事实（flare_service，`features` 调用于 `flare_page.dart`）**
- 🔴 RED：便血（日记 `bloody_stool` 为 `obvious|trace`，或排便细表 `blood>=1`）→ 文案"出现便血（日记/排便）"；腹痛 `pain>=8` → "腹痛 ≥8 分"（`flare_service.dart:38-61`）。
- 🟡 YELLOW：取最近 3 天，`pain[0]>pain[1]>pain[2]` → 连续加重；`diarrhea[0]>diarrhea[1]>diarrhea[2]` 或 `diarrhea[0]>=6 && diarrhea[0] > diarrhea[2]+2` → 连续升高/突增（`:63-74`）。无数据时也给 yellow（`:75-83`）。
- 追加仅一行"近期检验"文字（CRP/钙卫蛋白最新值，**不参与判定**，`:85-92`）。
- 不读用药、不读体重、不读体温、不持久化（`FlareResult` 仅内存对象，`:5-17,33-107`）。

**代码事实（ai_rules，`ai_rules_page.dart:48-104` 调用）**
- `labConsecutiveRise`：仅在最近三点**严格递增**（v[n-3]<v[n-2]<v[n-1]）时报"连续两次升高"（`ai_rules.dart:144-162`），仅对 CRP/ESR/钙卫蛋白 3 个指标（`ai_rules_page.dart:48-52`）。
- `bloodStreak`：便血连续 ≥2 天（`ai_rules.dart:164-190`；调用 `days: 2`）。
- `stoolSurge`：今日次数 ≥6 且比近 7 日均值高 ≥3（`ai_rules.dart:192-216`）。
- `medBeforeAfter`：用药前后均值对比（文字，不判定异常，`:218-247`）。
- 趋势方向：末段 vs 首段均值，相对幅度 <10% 视为稳定（`:79-93`）。

**指定规则逐条核对**

| 规则 | 现状 | 证据 |
|------|------|------|
| 淋巴细胞 <1.1 | **查无**（仅 `lab_panels.dart:71-77` 的 `refMin:1.1` 用于录入时 flag，无专门预警/文案） | 全仓 `淋巴细胞` 仅命中套餐/趋势页/一致性测试 |
| CRP≥5 且 FCP≥200 联合规则 | **查无** | 仅 `lab_panels.dart:62,69` 各自参考上限；flare 只把最新值拼成文字（`flare_service.dart:85-92`） |
| 体重 4 周下降 ≥5% | **查无**（无体重字段，见 §2.11） | — |
| 注射逾期文案 | **有（仅倒计时文案）**：首页"逾期 N 天"（`dashboard_tab.dart:80`）、详情页"已逾期 N 天"（`activity_detail_page.dart:222`）；无通知/预警条目 | — |
| 监测/复查逾期 | **查无**（复查提醒只调度未来时间，过期条目直接跳过：`reminder_prefs.dart:136-153`；无"逾期"告警） | — |
| 单指标连续异常 | **仅"连续两次升高"**（严格递增三点，`ai_rules.dart:150-160`）；无"连续异常（跨参考范围）"规则 | — |
| 新发异常（首次越界） | **查无**（flag 仅录入/展示用：`lab_panels.dart:28-34`、`activity_service.dart:13-17`） | — |

**关键代码片段**（RED 判定，`flare_service.dart:48-53`）
```dart
    if (bloody || bathBlood) {
      reasons.add('出现便血（日记/排便）');
    }
    if (pain >= 8) {
      reasons.add('腹痛 ≥8 分');
    }
```

**结论：部分**。PRD 所述"三级预警 + 规则版连续升高/便血连续/排便突增"**支持**；但任务书点名的 LYM<1.1、CRP≥5 且 FCP≥200、体重 4 周下降 ≥5%、监测逾期、新发异常均**查无**；"注射逾期"仅有倒计时文案，无告警规则。v1.3 若要写这些规则，必须标"未实现/新增需求"。

---

### 2.13 时间线事件类型

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:343-350`：「**时间线事件类型**（⚠️ 缺 2 类）：- 🔴 疾病事件（确诊、复发、并发症）— ❌ 未实现 - 🟡 检查事件（检验、影像、内镜、病理）— ✅ - 💊 用药事件（开始/调整/停用药物）— ✅ - 🏥 手术事件 — ✅ - 💉 注射事件 — ✅ - ⚠️ 不良反应事件 — ❌ 未实现（副作用表无界面，见 §2.2.2）- ➕ 生活质量评估事件」

**代码事实**
- `TimelineRepository.events()` 聚合的本机事件 `type` 共 **8 种**：`lab`、`med`、`med_end`、`inj_done`、`inj_plan`、`exam`、`surgery`、`qol`（`repositories.dart:510-580`；每类字段见 `:514-520,523-539,541-550,552-560,562-570,572-580`）。
- 筛选 Tab：全部/检验/用药/注射/检查/手术/量表（`timeline_page.dart:22-30`）。
- **无疾病事件**（无 disease event 表/代码）；**无不良反应事件**（`adverse_events` 表存在但未被 TimelineRepository 查询，见 `repositories.dart:506-584` 全函数无 adverse）。
- **也无"每日症状打卡"事件**（timeline 不读 symptom_diaries）；PRD 未提此点，v1.3 可补。
- 无点击详情、无导出、无缩放（`timeline_page.dart:81-207`；列表项无 onTap 到详情）。

**关键代码片段**（`repositories.dart:514-520`）
```dart
    for (final r in labs) {
      out.add({
        'date': r['date'],
        'type': 'lab',
        'title': '检验 · ${r['hospital'] ?? ''}',
        'subtitle': '来源 ${r['source']}',
      });
    }
```

**结论：支持**（PRD 对"疾病/不良反应事件 ❌"的判断与代码一致）。补充：实际事件类型为 8 种细粒度 type；**症状打卡事件也未进时间线**。

---

### 2.14 每日打卡字段

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:440-453`：「**记录项目**（✅ 全部实现）：| 腹痛 0-10 | 腹泻次数+Bristol | 便血 | 腹胀 | 疲劳 | 恶心 | 口腔溃疡 | 关节痛 | 自定义 | 整体感受」。
- `docs/IBD病程管理程序PRD-v1.2.md:464-470`：排便记录项「时间/次数/Bristol/紧迫感/便血/黏液」。

**代码事实（App 打卡页 `symptom_page.dart` + 本地表 `symptom_diaries`）**
已有字段：
- 腹痛 0–10（`:542-592`）；排便次数（`:593-631`）；腹泻次数（`:632-670`）；**Bristol 粪便性状 1–7**（`:671-767`）；**便血**（无/擦拭有/明显，`:768-828`）；**紧迫感**（`:830-839`）；**黏液**（`:840-849`）；腹胀（`:887-934`）；恶心（`:915-924`）；疲劳（`:925-934`）；口腔溃疡（`:949-958`）；关节痛+部位（`:959-1008`）；自定义关注项（`:1034-1040`）；睡眠时长/质量/入睡困难/夜醒（`:1042-1131`）；压力水平/来源（`:1132-1174`）；整体感受（`:1175-1215`）。
- 对应列：`symptom_diaries` 基础列（`local_db.dart:192-204`）+ v5 补 urgency/mucus/bowel_count（`:298-320`）+ v6 补 oral_ulcer/joint_pain/joint_pain_site/custom_items/sleep_*/night_wakes/stress_*（`:321-348`）。
- 服务端实体只有 `painLevel, diarrheaCount, stoolType, bloodyStool, bloating, fatigue, nausea, overallFeeling, bowelCount, urgency, mucus`（`symptom-diary.entity.ts:29-61`）；**缺 oralUlcer/jointPain/customItems/sleep/stress**（与 PRD §3.2 `:705-707` 一致）。

任务点名的字段：
- **体重：查无**（打卡页、本地表、服务端实体、迁移全无；搜 `体重\|BMI\|kg\|身高` 无相关）。
- **发热/体温：查无**（全仓无 `temperature|体温|fever|发热` 字段；flare 的 🔴 也因此缺发热条件，与 PRD `:480,:488` 一致）。
- **夜间症状：查无**（只有睡眠"夜间醒来次数" `night_wakes`，不是 IBD 夜间症状；`夜间` 仅命中 `nightWakes`）。
- **粪便性状：有**（Bristol `stool_type`，`:671-767`；本地表 `:197`；服务端 `:35-36`）。
- **黏液：有**（`mucus`，`:840-849`；v5 迁移 `:301`；服务端 `:60-61`）。
- **紧迫感：有**（`urgency`，`:830-839`；v5 迁移 `:300`；服务端 `:57-58`）。

**关键代码片段**（`local_db.dart:191-203`，可见无体重/发热列）
```dart
      CREATE TABLE IF NOT EXISTS symptom_diaries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        pain_level INTEGER,
        diarrhea_count INTEGER,
        stool_type INTEGER,
        bloody_stool TEXT,
        bloating INTEGER,
        fatigue INTEGER,
        nausea INTEGER,
        overall_feeling TEXT
      )
```

**结论：部分**。PRD 表中已列项目**全部属实**（腹痛/腹泻/Bristol/便血/腹胀/疲劳/恶心/口腔溃疡/关节痛/自定义/整体感受）；但任务点名的**体重、发热、夜间症状三项查无**——若 v1.3 要把它们写成"已实现"，即为不符。

---

### 2.15 用药调整（服务端 API 与 App UI）

**PRD v1.2 原句**
- `docs/IBD病程管理程序PRD-v1.2.md:263-267`：「**记录维度**（⚠️ 部分实现）：- 药物切换链 + 停药原因 ✅（服务端另有 adjust/pause/resume/stop/switch 换药链 API ➕）- 副作用记录…⚠️ 数据表与服务端 API 已有，**App 端无录入/展示界面** - 剂量调整独立记录 ❌（编辑为"停旧建新"，无独立调整事件）- 停药时长及恢复过程 ✅（由起止日期体现）」
- `docs/IBD病程管理程序PRD-v1.2.md:247`：「**药物信息字段**（⚠️ 一处差异：无独立"适应症"字段，并入备注/调整原因）」

**代码事实（服务端：齐全）**
- 端点：`POST /medications`、`PATCH /medications/:id`、`POST /medications/:id/adjust`、`POST /medications/:id/pause`、`POST /medications/:id/resume`、`POST /medications/:id/stop`、`POST /medications/switch`、`POST/GET /medications/:id/adverse-events`、`GET /medications/timeline`（`medication.controller.ts:21-113`）。
- `adjust()`：停旧（status=stopped,endDate=effective）+ 开新（同药、新剂量/频次、reason="剂量调整：…"），**不支持 route 变更**（`AdjustMedicationDto` 只有 `dosage/frequency/reason/effectiveDate`，`medication.service.ts:24-29,116-145`）。
- `switch()`：停旧 + 建新（`medication.service.ts:165-181`）。
- 副作用：`addAdverseEvent/listAdverseEvents`（`:224-244`）。
- **无"变更事件"表/类型字段**：所有历史靠多条 `medications` 记录 + `reason` 文本；`status` 三值（active/paused/stopped）；`indication` 在 DTO 中存在但实体/迁移无列、create 也未写入（`medication.entity.ts:12-60`；`medication.service.ts:85-105`）——即"适应症"仍无有效字段。

**代码事实（App：只有停用 + 编辑=停旧建新）**
- 停用：`medication_page.dart:68-89`（弹窗填原因 → `MedicationRepository.stop` 写 status=stopped/end_date/reason）。
- 编辑：`medication_edit_page.dart:213-215` 先 `stop(..., reason:'编辑')` 再 `insert` 新记录。
- **无 pause/resume/switch/adjust 的 UI**；无副作用录入/展示 UI（`features/medication/` 无 adverse 调用；仅有 repo 方法 `repositories.dart:114-142` 和 API client `ibd_api_client.dart:468-477`）。
- 频次与时间点联动存在（`medication_edit_page.dart:24-53,59`），但"隔日"等频次只影响提醒时间点选择，未做隔日调度（PRD §2.5.3 已注明）。

**关键代码片段**（`medication.service.ts:122-141`）
```ts
    const stopped = await this.meds.save({
      ...med,
      status: "stopped",
      endDate: effective,
      reason: `${med.reason ? med.reason + "；" : ""}调整：${dto.reason}`,
    });
```
（随后 `:129-143` 开新记录，`reason: "剂量调整：…"`。）

**结论：部分**。服务端 adjust/pause/resume/stop/switch **齐全**；App UI **只有 stop（及编辑=停旧建新）**，缺 pause/resume/switch/adjust/副作用入口——与 PRD 自述一致；但 PRD 若在 v1.3 写"App 支持整套用药变更"将不符。任务书点名的变更史类型 start/stop/dose_change/route_change/frequency_change/hold/resume：**均无独立事件记录**，其中 `route_change` 连 adjust 也不支持（仅 PATCH 全量更新可改 route，无审计语义）。

---

## 三、PRD v1.2 明确不符/需改写点（汇总，带 file:line）

| # | PRD v1.2 位置与原句（节选） | 代码事实（file:line） | 处置建议 |
|---|---------------------------|----------------------|----------|
| D1 | `:293`「延迟注射后自动调整后续排期 ❌ 未实现（记录实际日期后，后续计划日期不顺延）」 | 服务端 `injection.service.ts:137-190` 已实现顺延（`:168-187`，默认 `rescheduleDelay=true`）；App `repositories.dart:192-200` 未实现且无 API 调用（`ibd_api_client.dart:295-310` 无调用方） | 改为"⚠️ 服务端已实现；App 未接入、不顺延"，分端表述 |
| D2 | `:499`「SF-36 ✅ 36 题；…自算 8 域 0–100 域分」 | 36 题/统一 0–4/无 PCS-MCS 属实（`survey_kit.dart:135-180`；`sf36_scoring.dart:3`）；但域映射为 GH1/PF8/RP5/BP2/VT4/SF5/RE5/MH5，**非原版**（`sf36_scoring.dart:26-35`）；条目为改写版 | 改为"改写版自评量表（非标准 SF-36）"，补域条目数表；不得称"标准 8 域" |
| D3 | `:500`「简版 IBDQ ⚠️ 简版 10 题」（未写选项/总分） | 10 题属实；选项 1–5、总分 10–50（`survey_kit.dart:95-101,127-131`；`survey_page.dart:45`），**非 SIBDQ 1–7/10–70** | 补"1–5 分、10–50；不可与 SIBDQ 文献值对比" |
| D4 | `:702`「Injection ✅ 与目标模型一致」 | 字段基本一致（`injection.entity.ts:25-48`），但**无 next***；App phase 为伪标签（`injection_page.dart:124`）；服务端 4 协议库未被 App 使用（`injection.protocols.ts:29-104` vs `protocols.dart:40-67` 死代码） | 改状态（部分）；补"无下次预约字段、无协议接入" |
| D5 | `:237`「仪表盘已按正则提取 Limberg / SES-CD 趋势」 | 正则与展示在**活动度详情页**（`activity_service.dart:52-72`；`activity_detail_page.dart:94-110,267-275`），首页卡不含趋势（`dashboard_tab.dart:49-63`） | 表述精确化（非错，但需 file:line 校正） |
| D6 | PRD 无"疫苗/感染筛查""体重/BMI/特殊饮食阶段""就诊/住院/急诊记录"章节（查无） | 页面/表/接口均查无（见 §2.11） | **新增"未实现模块"章节**，避免 v1.3 默认写成已实现 |
| D7 | PRD 无"待核对队列/已处理 PDF 清单/解析去重"表述（任务书要求核验） | 三者均查无（见 §2.10） | 若 v1.3 要写，必须标"未实现（当前为页内联核对、无清单、无去重）" |
| D8 | `:440`「记录项目（✅ 全部实现）」 | 表内 10 项属实；但**体重/发热/夜间症状查无**（见 §2.14） | 保留"表内项目 ✅"；若新增三项须标 ❌/新增需求 |
| D9 | `:480`「🔴 级缺"发热>38°C"条件（无体温字段）」 | 属实（无体温字段） | 无需改；若 v1.3 加发热预警需先加字段 |

> 说明：D5/D9 属"表述可更精确/已如实"，不是硬性失实；D1–D4、D6–D8 是 v1.3 必须处理的差异。

---

## 四、必须改/建议改的数据模型字段（给 PRD v1.3 的落地建议）

> 仅按代码现状给出"要支撑 PRD v1.3 新表述，需要新增/调整的模型字段"，不涉及具体迁移实现。

1. **量表（若要标准 SF-36 / SIBDQ）**
   - 现模型：`quality_surveys(id, date, kind, total, detail_json)`（`local_db.dart:267-281`；`repositories.dart:690-707`），域分/band 全塞 `detail_json`。
   - 需新增（若要结构化/可查询）：`scale_version`（区分 SF-36 改写版/标准版、IBDQ 1–5/1–7）、`domain_scores` 独立表或 JSON 明确 schema、`reverse_scored_items`/计分算法版本。
2. **检验记录（若要做 confidence / aliases / 指标级来源 / 去重）**
   - `lab_items` 增：`confidence`（float/null）、`aliases`（jsonb）、可选 `source`（指标级，当前为记录级 `labs.source`/`lab_results.source`）。
   - 去重：`(patient_id, date, name_norm)` 唯一键或合并策略；当前无（`lab.service.ts:44-68`、`repositories.dart:12-48`）。
3. **解析链路（若要做待核对队列 / 已处理清单）**
   - `parse_jobs` 已有 `status`（含未使用的 `awaiting_review`，`parse-job.entity.ts:38`）、`engine`、`reportDate`、`sourceDeleted`。
   - 需增加：`review_reason`（失败分类/待核对原因）、`file_hash` 或 `objectKey` 唯一约束（已处理清单/防重复上传）、客户端列表接口消费。
   - 日期：`reportDate` 已存在；App 端不入库报告日期，若要在 App 展示/使用解析日期，需在本地 `labs` 增加 `report_date` 与 `date` 区分。
4. **检查记录（若要做结构化评分/疾病活动度）**
   - 现 `exams.score TEXT`（`local_db.dart:241`）。需加：`score_type`（Limberg/SES-CD/IBUS-SAS/其他）、`score_value`（数值/分级）、`activity_score`（若与评分分离）；否则只能维持正则提取。
5. **注射（若要"下次预约"与顺延审计）**
   - 现无 `next*` 字段（`injection.entity.ts:25-53`；`local_db.dart:178-190`）。
   - 需加：`nextAppointmentDate`（或由最早未完成 plannedDate 派生并在 PRD 说明）、`rescheduleLog`/`delayDays`/`shiftedCount`（当前只在 complete 响应返回，未落库，`injection.service.ts:189`）。
6. **预警/时间线（若要规则化与事件化）**
   - 当前规则硬编码（`flare_service.dart:33-107`；`ai_rules.dart:144-216`），无规则表；若要 LYM<1.1 / CRP≥5&FCP≥200 / 体重 4 周下降≥5% / 监测逾期，需要规则配置表 + 阈值来源。
   - 时间线：若要"疾病事件/不良反应事件"，需新增 `disease_events`（或通用 `timeline_events`）；`adverse_events` 已有表但未聚合进 timeline（`repositories.dart:506-584`）。
7. **缺失模块（全新表，均查无）**
   - 疫苗/感染筛查：`vaccinations` / `infection_screenings`。
   - 营养：`weight_logs`（体重/身高/BMI）、`nutrition_assessments`（特殊饮食阶段/依从性）。
   - 就诊/住院/急诊：`visits` / `hospitalizations` / `emergency_visits`（当前只有就诊摘要文本，`clinical_pages.dart:366-445`）。
8. **用药变更史（若要 eventType：start/stop/dose_change/route_change/frequency_change/hold/resume）**
   - 现 `medications` 仅状态+起止+reason；`adjust` 只支持 dosage/frequency，不支持 route（`medication.service.ts:24-29,116-145`）。
   - 需新增 `medication_events(event_type, effective_date, from_value, to_value, reason)`；当前"停旧建新+reason 文本"无法区分 dose_change/frequency_change/route_change/hold/resume。
9. **打卡（若要体重/发热/夜间症状）**
   - App `symptom_diaries` 与服务端实体均无体重/体温/夜间症状列（`local_db.dart:192-204,298-348`；`symptom-diary.entity.ts:29-61`），需新增 `weight_kg`、`temperature_c`、`night_symptoms`，并同步迁移/服务端实体/DTO。
10. **来源与别名（若 v1.3 沿用"三档来源"）**
    - 记录级 `source` 已支持三值（`lab-result.entity.ts:32-33`；App `lab_entry_page.dart:493-495`）；但历史/迁移数据无回填（`parse-source.ts:24-32`），PRD 应继续写"旧数据不回填"。

---

## 五、附录：查无项与搜索关键词/范围（可复核）

| 查无项 | 搜索关键词 | 搜索范围 | 结果 |
|--------|-----------|----------|------|
| PHQ-2 / GAD-2 / GAD-7 | `GAD\|GAD-2\|GAD-7\|PHQ-2\|PHQ2\|gad2\|焦虑` | apps/mobile/lib、apps/web/src、apps/miniapp/src、apps/doctor-web/src、services/api/src、services/parse-worker/app、packages | 0 命中（仅 repositories.dart:682 注释） |
| confidence / 置信度 | `confidence\|置信度` | 同上（*.dart,*.ts,*.tsx,*.py） | 0 命中 |
| aliases | `aliases\|别名`（检验记录） | 同上 | 仅 ParseSkill rule `alias`；无记录级 aliases |
| activity_score / 评分类型 | `activity_score\|activityScore` | 同上 | 0 命中（仅 docs） |
| IBUS-SAS 解析 | `IBUS\|ibus` | 同上 | 仅 docs 命中，代码 0 |
| 待核对队列 | `待核对\|awaiting_review\|review_queue\|needsReview` | 全仓 | 仅 `parse-job.entity.ts:38` 枚举定义；无赋值/UI |
| 已处理 PDF 清单 | `已处理\|listParseJobs\|parse.*history` | 全仓 | 无客户端清单；服务端仅 GET /parse/jobs（`parse.controller.ts:24-27`） |
| 解析去重 | `dedupe\|duplicate\|去重\|重复` | 全仓 | 仅食物/打卡同步/迁移注释，与 PDF/检验无关 |
| 下次预约日期 | `下次预约\|预约日期\|nextAppointment` | 全仓 | 0 命中（由最早 pending plannedDate 派生：`activity_service.dart:41-50`） |
| 自动改写医嘱 | `医嘱\|auto.*prescri\|医嘱优先` | 全仓 | 仅免责/提醒文案；无回写逻辑 |
| 疫苗/感染筛查 | `疫苗\|vaccin\|感染筛查\|screening` | 全仓 | 仅图标（`shell_page.dart:60` 等）与英文 PRD 文档 |
| 体重/BMI/身高 | `体重\|BMI\|kg\|身高`（精确词） | 源文件 | 仅 `injection.protocols.ts:65` 剂量文案"体重按说明书" |
| 住院/急诊/就诊记录 | `住院\|hospitaliz\|admission\|急诊\|visit` | 源文件 | 住院：仅脱敏正则；急诊：仅 flare 文案；visit：仅就诊摘要/visit-summary |
| 特殊饮食阶段 | `特殊饮食\|饮食阶段\|nutrition` | 源文件 | 仅食物营养汇总/文案，无阶段模型 |
| 发热/体温 | `发热\|体温\|fever\|temperature` | 源文件 | 0 命中 |
| 夜间症状 | `夜间症状\|nocturnal` | 源文件 | 0 命中（仅有 `nightWakes` 夜醒次数） |
| 疾病事件 | `疾病事件\|disease_event\|relapse\|复发` | 源文件 | 0 命中（仅文档/PRD） |
| 不良反应进时间线 | `adverse.*timeline\|timeline.*adverse` | 源文件 | 0 命中（`repositories.dart:506-584` 不查 adverse_events） |

**其它已核验但未单列的事实**
- 服务端模块目录仅 13 个：`doctor, drug-review, geo-community, injection, lab, medication, parse, patient, push, reminder, skill, symptom, sync`（`services/api/src/modules/`），无 exam/surgery/vaccine/visit/nutrition。
- 服务端实体 21 个、迁移 `CREATE TABLE` 24 张，均无 exam/surgery/vaccine/visit/nutrition/weight 表。
- App 底部 5 Tab（`shell_page.dart:35-41`）；分析页 14 个入口（`analysis_tab.dart:29-168`），无疫苗/营养/就诊记录入口。
- 提醒：注射提前量默认 `{3}`、允许 `{0,1,2,3,7}`（`reminder_prefs.dart:12-16`）；用药提醒默认关、默认 9 点（`:39-68`）；复查提醒为一次性条目、过期跳过（`:70-95,136-153`）；通知文案脱敏（`reminder_copy.dart:11-24`）。
- 服务端 complete 顺延可与 `rescheduleDelay=false` 关闭；App API client 已有该参数（`ibd_api_client.dart:295-310`）但无 UI 调用。

---

*本卷完。所有结论可按上列 `file:line` 逐条复核；未修改任何仓库文件，未执行构建/测试/git 操作。*
