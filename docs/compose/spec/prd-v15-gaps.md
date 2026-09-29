---
feature: prd-v15-gaps
status: delivered
updated: 2026-09-23
branch: feature/prd-v15-gaps
commits: 66820d8..0da20a7
---

# PRD V1.5 缺口批（G1–G5）

## Report

**What was built** — 一次交付 PRD V1.5 五个缺口：本地库 v5→v6 增 10 列支撑日记补全与睡眠/压力打卡；打卡页新增溃疡/关节痛/自定义项、睡眠压力区、昨日快捷模板与周一对齐的 6 周热力月历；首页疾病活动度卡 + 详情页（CRP/ESR/钙卫状态灯、注射倒计时、Limberg/SES-CD 正则趋势、用药卡、待打前 3 条）；年度报告默认最近完整年自动构建并输出同比与检查/手术汇总；PC Web 增加 xlsx 双 sheet 导出与 `/skills` Skill 模板管理（localStorage CRUD + 导入校验）。顺带清理 `api-client` 重复方法使 `@ibd/web` typecheck 归零（解锁 T2.7）。

**Verification** — `flutter analyze --no-fatal-infos` PASS（7 infos）；`flutter test` PASS **63** tests（含 v6 迁移、severity/quick-template/activity/年报同比、打卡 UI、首页与活动度详情 widget）；`pnpm --filter @ibd/web typecheck` PASS；`@ibd/api` / `@ibd/domain-types` typecheck PASS。独立审阅首轮 REQUEST_CHANGES（4 critical）→ 修复 `0da20a7` → 复审 **APPROVE**。

**Journey log** — 本机 flutter test 需先补 `ProgramFiles(x86)` 环境变量（缺失会静默 exit 1）；pnpm 不在 PATH，经 hermes `corepack pnpm` 调用。`apps/web` typecheck 曾被 HEAD 上 api-client 重复 `uploadBytes`/`waitParseJob` 卡死（baseline 可复现），属 T2.7 同根因。打卡页加长后测试视口 2800 不够，调至 4200；首页模块卡 GridView 曾溢出 7.8px，改 aspect 1.15 + spaceBetween。Dashboard 的 7 天/60 天 listPending 必须分查询，否则快捷入口计数语义被静默改掉。

## [S1] Problem

PRD 缺口审计（prd-gap-audit S2.3）确认 G1–G5 为 V1.5 里程碑未落地能力，现已合入 main 并进入 worklist：

| ID | PRD | 缺口 |
|----|-----|------|
| G1 | §2.6.1 | 首页无疾病活动度仪表盘（炎症状态灯 / Limberg / SES-CD / 用药卡 / 倒计时） |
| G2 | §2.7.1 | 打卡缺口腔溃疡、关节痛+部位、自定义项；无日历热力；无「和昨天一样」快捷模板 |
| G3 | §2.6.2 | 年报无同比、无检查/手术汇总、需手选年份（C3 裁定补「自动」体验） |
| G4 | §4.2.2 / §2.7.5 | 无睡眠/压力每日打卡 |
| G5 | §4.2.4 | PC Web 仅 JSON/CSV，无 Excel；无 Skill 模板管理表单 |

## [S2] Design

### S2.1 范围与总原则

- 仅本机/local-first：App 新字段进 SQLCipher 本地库；Web 数据留 localStorage，不新增服务端接口。
- 不改打卡既有字段语义与排便细表同步链路；只增列与增 UI。
- 不做 G6/G7、T6.x、推送/真机项。
- i18n：新文案接入现有中英词典机制（有 key 用 key；与既有打卡页一致的中文硬编码策略保持统一——打卡页现为中文直写，新 UI 跟随所在文件既有做法）。

### S2.2 数据模型（G2 + G4）— 本地库 v5 → v6

`symptom_diaries` 增列（`_addColumnIfMissing` 幂等，同 v5 模式）：

| 列 | 类型 | 含义 |
|----|------|------|
| `oral_ulcer` | INTEGER | 口腔溃疡 0/1 |
| `joint_pain` | INTEGER | 关节痛 0/1 |
| `joint_pain_site` | TEXT | 部位，逗号分隔预设（膝/踝/手/背/其他） |
| `custom_items` | TEXT | JSON 数组 `[{"label":"…","value":"…"}]`，null/`[]` 表示无 |
| `sleep_hours` | REAL | 睡眠时长小时，null=未记 |
| `sleep_quality` | INTEGER | 1–5 |
| `sleep_insomnia` | INTEGER | 入睡困难 0/1 |
| `night_wakes` | INTEGER | 夜醒次数 |
| `stress_level` | INTEGER | 压力 1–10 |
| `stress_source` | TEXT | 工作/家庭/疾病/其他，可空 |

- 仍保持 `date UNIQUE` 一行一天；睡眠/压力并入同一次「保存今日打卡」。
- `SymptomRepository.upsert` 扩展可选参数；`getByDate` 回读兼容 null。
- `packages/domain-types` `SymptomDiary` 同步增可选字段（Web/共享侧类型对齐，不强制 Web UI 展示）。
- 迁移版本号 `version: 5 → 6`；新表测试仿 `db_migration_v5_test.dart`。

### S2.3 G2 打卡页增强（`symptom_page.dart`）

1. **其他症状区扩展**：恶心、疲劳之后新增「口腔溃疡」开关、「关节痛」开关（开则显示部位 FilterChips）、自定义项（列表 + 添加对话框 label/value，可删）。
2. **睡眠与压力区**（G4，独立 `_SectionCard`）：时长 slider 0–12h、质量 1–5 chips、入睡困难开关、夜醒次数 stepper/slider、压力 1–10 slider、压力来源 chips（可空）。全部可选，不填保存为 null。
3. **快捷模板**（页顶，仅当昨日有记录时显示）：
   - 「和昨天一样」：复制昨日全部字段到今日表单（`overall_feeling` 保持 `same`）；
   - 「比昨天好 / 差」：复制昨日字段但 `overall_feeling` 分别置 `better` / `worse`；
   - 复制只预填不落库，用户仍点保存；复制后 `_saved=false`。
   - 无昨日记录时隐藏或禁用并提示。

### S2.4 G2 日历热力

- 位置：打卡页「快捷模板」下方或分析页新入口——**定为打卡页内嵌近 6 周月历卡**（高频场景，与 PRD「日历视图」一致），分析页不重复做。
- 严重度 `severity ∈ 0..10`（纯函数，便于单测）：

```
bloodPts = none→0, trace→1.5, obvious→3（其余按 0）
severity = clamp( pain*0.5 + min(bowelCount??diarrheaCount,10)*0.3 + bloodPts , 0..10 )
```

- 颜色：无记录→灰；0–3 绿；4–6 黄；7–10 红（对齐 `IbdColors.success/warning/danger`）。今日描边高亮。点某日若有记录可跳转说明（点选仅高亮显示当日摘要文本，不支持补录历史日——补历史日超范围）。

### S2.5 G1 疾病活动度仪表盘

**入口**：首页 `DashboardTab` 在「今日管理」与「快捷入口」之间插入「疾病活动度」卡；点卡进入详情页 `ActivityDetailPage`（analysis 下新文件）。

卡内（首页，紧凑）：

| 元素 | 数据 | 行为 |
|------|------|------|
| 炎症三联状态灯 | 最近一次检验中 `超敏C反应蛋白` / `血沉` / `粪便钙卫蛋白` 的 `flag`（lab_panels refMax：5 / 15 / 200） | `high`→红，`low`/正常→绿，无数据→灰；显示数值+单位+日期 |
| 下次注射倒计时 | `InjectionRepository.listPending(withinDays: 60)` 最近一条 | `plannedDate - today` 天数；无→「无待打针」 |
| 当前用药摘要 | `listCurrent()` 前 2 项 `drugName+dosage`，超出显示「等 N 项」 | 点进 `MedicationPage` |

详情页追加：

| 元素 | 数据 | 行为 |
|------|------|------|
| 三联全量 | 同卡 + 历史最近 5 次值列表 | — |
| Limberg 趋势 | `ExamRepository` 按日期倒序，`score`/`findings` 正则 `Limberg\s*([0-4IViv]+)` 提取 | 无匹配→「暂无 Limberg 记录」；列出 日期+分级 |
| SES-CD 趋势 | 同上正则 `SES-?CD\s*([0-9.]+)` | 同上 |
| 用药卡 | `listCurrent()` 完整卡片列表 | 点击跳用药页 |
| 注射倒计时 | 同首页 + 下 3 条待打列表 | 跳注射 Tab |

- 解析失败不抛错，按无记录处理。自由文本 score 不建新表（审计已知现状）。
- **复查倒计时不做**：无「下次复查」数据模型，列入 Out of Scope。

### S2.6 G3 年度报告补齐（`annual_report.dart` + `annual_report_page.dart`）

1. **同比**：`AnnualReport` 增 `prev: AnnualReport?`（year-1，同 builder 一次构建两份）与 `CompareDelta`（labCount/symptomDays/injectionCount/avgPain 的差值与方向）；`toText()`/`toJson()` 输出对比段。
2. **检查/手术汇总**：builder 增 `ExamRepository`/`SurgeryRepository`，按年过滤，输出计数 + 每条日期/类型/结论（文本截断 80 字）；UI 报告页两小节。
3. **自动体验（C3/G3）**：进入报告页**默认自动选中最近完整年份**（今年>1月1日则为去年-1，否则去年），无需手选即可看到报告；构建结果不落新表，保留手动切换年份与重新生成。不加后台定时任务。

### S2.7 G5-a PC Web Excel 导出（`DataExport.tsx`）

- 新增依赖 `xlsx`（SheetJS），`apps/web` `pnpm add xlsx`（lockfile 更新属预期）。
- 「导出 Excel」按钮：同一 `collect()` 数据 → 两个 sheet：`labs`（date/nameNorm/value/unit）、`clinical`（kind/date/type/conclusion）；`XLSX.writeFile` 下载 `ibders-export-YYYY-MM-DD.xlsx`。
- JSON/CSV/导入/打印保持不动。

### S2.8 G5-b Skill 模板管理表单（Web 新路由 `/skills`）

- 新页 `apps/web/src/pages/Skills.tsx`，导航加「Skill 模板」。
- 数据：`localStorage['ibd_web_skills']`，元素为 `ParseSkill`（domain-types：hospital/reportType/version/dateExtraction/items[]）。
- UI：左侧已存模板列表（hospital · reportType · version）；右侧编辑表单——基本信息四字段 + items 动态行（name/alias/pattern/unit/refMin/refMax，增删行）；保存/删除/导出单条 JSON/导入 JSON。
- 校验：hospital、reportType、至少 1 条 item、每条 name+pattern 非空；非法时行内提示，不写入。
- 不连服务端 Skill 社区（T6.1 另议）；不改 parse-worker。

### S2.9 错误与边界

- 迁移重入：列已存在静默跳过（沿用 `_addColumnIfMissing`）。
- `custom_items` JSON 解析失败→当空列表，不崩。
- 快捷模板：昨日记录缺列（旧数据）→ 对应字段用今日默认值。
- Excel 导出：空数据仍生成含表头的 xlsx。
- 全部新 UI 遵守现有 `IbdColors`/卡片风格；`flutter analyze` 零 error。

### S2.10 测试边界

| 测试 | 覆盖 |
|------|------|
| `db_migration_v6_test.dart` | v5→v6 新列存在；upsert/getByDate 往返 |
| `checkin_quick_template_test.dart` | 昨日→今日复制、feeling 覆盖、无昨日 |
| `symptom_severity_test.dart` | severity 公式边界（无排便列、blood 全档、clamp） |
| `activity_lights_test.dart` | flag→灯色、缺指标→灰；Limberg/SES-CD 正则样例 |
| `annual_report_compare_test.dart` | 同比差值、检查/手术入文、默认年份选择纯函数 |
| Web | `pnpm --filter @ibd/web typecheck` 零 error（无既有测试框架，不新建） |

## [S3] Out of Scope

- G6 食物-排便、G7 SF-36 标准计分、T6.x、推送凭据、真机验收。
- 复查倒计时（无数据模型）；历史日期补打卡；年报后台定时任务与年报表持久化。
- 服务端/Skill 社区接口；parse-worker 改动；医生端。
- 打卡页 i18n 全面改造（维持各文件既有中文策略）。

## Tasks

- [x] T1: 本地库 v6 迁移 + `SymptomRepository`/domain-types 扩展 — acceptance: `db_migration_v6_test` 通过，`flutter analyze` 无 error (covers: S2.2)
- [x] T2: 打卡页 G2+G4：溃疡/关节/自定义 + 睡眠压力区 + 快捷模板 — acceptance: quick_template 与页测试通过，保存往返含新字段 (covers: S2.3; depends: T1)
- [x] T3: 打卡页日历热力 + severity 纯函数 — acceptance: severity 单测过，月历按灰/绿/黄/红渲染（周一开头） (covers: S2.4; depends: T1)
- [x] T4: 首页活动度卡 + 详情页（状态灯/Limberg/SES-CD/用药/倒计时） — acceptance: activity_lights + activity_widget 测试过 (covers: S2.5)
- [x] T5: 年报同比 + 检查手术汇总 + 默认最近完整年份 — acceptance: annual_report_compare 测试过，报告页含对比与汇总段 (covers: S2.6)
- [x] T6: Web Excel 导出（xlsx 两 sheet） — acceptance: `@ibd/web typecheck` 通过，导出调用 writeFile 含 labs/clinical (covers: S2.7)
- [x] T7: Web Skill 模板管理表单 `/skills` — acceptance: typecheck 通过；localStorage CRUD + 校验（含导入路径）完整 (covers: S2.8)
- [x] T8: worklist G1–G5 状态同步 + 全量验证记录 — acceptance: 清单项状态与实现一致，Verify 命令全过 (covers: S2.1; depends: T1,T2,T3,T4,T5,T6,T7)
