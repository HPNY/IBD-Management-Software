# IBD 病程管理 PRD v1.3 — 医学标准口径证据卷

> 用途：为 PRD v1.2 → v1.3 的医学口径修正提供**可引用的标准依据**。本文只核实"标准怎么定义/阈值是多少/说明书怎么写"，**不含任何诊断结论或治疗建议**；凡涉及患者个体是否需要检查、用药、接种，均由临床医生决定。
>
> 检索时间：2026-11-02（Asia/Hong_Kong）。引用类型逐条标注：
> **【指南阈值】** = 学会指南给出的决策界值；**【实验室参考范围】** = 检验报告/试剂厂商给出的参考区间；**【量表官方计分】** = 量表发布方计分说明；**【说明书】** = FDA/监管标签；**【综述/专家共识】** = 非指南级证据；**【不确定】** = 未找到可访问的一手依据。
>
> 关联文件：PRD 原文 `docs/IBD病程管理程序PRD-v1.2.md`；Skill 侧口径 `~/.dsh/skills/crohns-lab-tracker/SKILL.md`（检验列 `<200`）、`~/.dsh/skills/medical-report-parser/SKILL.md`（Limberg I–IV / IBUS-SAS / SES-CD 0-2/3-6/7-15/>15）；本仓库 SF-36 实现说明 `docs/compose/spec/sf36-standard-scoring.md`。

---

## 0. 结论速览

| 主题 | 标准口径（一句话） | PRD v1.2 的问题 | 证据强度 |
|---|---|---|---|
| 粪便钙卫蛋白 FCP | 无统一参考范围；实验室/试剂常以 50 µg/g 为阴性界值，综述把 100–250 µg/g 视为需复测的灰区，AGA 指南在"症状缓解+近期内镜缓解"用 **<150 µg/g** 排除活动性炎症、术后低危用 <50 | §2.1.3 把 `<200 μg/g` 写成唯一参考范围并称"肠道炎症金标准"，§2.1.3 趋势项写"钙卫蛋白 200 缓解线" | 指南（AGA）/ 综述（BIRD）/ 实验室参考范围 |
| SES-CD | 标准评分表总分 **0–56**（4 变量×5 段×0–3；狭窄项因"不能通过只能记一次"上限 11 分），0–60 是把狭窄项按 15 分算的算术误写；0–2/3–6/7–15/≥16 是文献常用分级、非原版验证自带阈值 | §2.1.4 只写"按正则提取 SES-CD 趋势"，无总分口径、无分级定义 | 指南/评分表（方案附表）/ 综述 |
| Limberg | 彩色多普勒肠壁血流半定量分级；GETECCU 指南定义为 **0–3 级**（0 无血流；1 为 1–2 点/cm²；2 为 3–5 点/cm²；3 为 >5 点/cm² 或血流出壁），部分资料记 I–IV；**不能单独代表疾病活动度** | §2.1.4/仪表盘把"Limberg 分级趋势"当独立指标，未限定需结合肠壁厚度/分层 | 指南（GETECCU）/ 综述 |
| IBUS-SAS | 全称 International Bowel Ultrasound Segmental Activity Score；0–100 加权分 = 4·BWT(mm)+15·i-fat+7·CDS+4·BWS；截断 23.8（活动）/40.0（中重度） | §2.1.4 一句"IBUS-SAS 未支持"，未区分"字段可记录"与"未做数值加权/趋势" | 专家共识（Novak 2021）+ IBUS 教学材料 |
| SIBDQ | 就是 10 题简版 IBDQ；每项 1–7 分，总分 **10–70**，分越高越好；**无公认统一界值** | §2.7.4 只写"IBDQ 简版 10 题"，未说明即 SIBDQ、未给 1–7/10–70 计分 | 综述（量表引用）/ 不确定（界值） |
| SF-36 | 标准 8 域条目数 **PF10/RP4/BP2/GH5/VT4/SF2/RE3/MH5**（35 题，第 36 题健康变化不计域）；条目按各自选项重编码到 0–100，域分=条目均值；PCS/MCS 需常模加权（T 分，均值 50/SD 10），RAND 官方计分**不含** PCS/MCS，且与 MOS SF-36 计分不同 | §2.7.4 承认"简化 0–4 计分+自算 8 域"，但仍以"SF-36"名义展示；实现域映射与标准条目构成不同，数值不可与标准分对照 | 量表官方计分（RAND）/ 综述（PCS/MCS 常模） |
| PHQ-2 / GAD-2 | PHQ-2=PHQ-9 前 2 题、GAD-2=GAD-7 前 2 题；各 0–3 分、总分 0–6；**≥3 为筛查阳性**，阳性应转完整 PHQ-9/GAD-7；PHQ-4=0–12 | PRD 只有 PHQ-9，无 PHQ-2/GAD-2 月度轻量筛查 | 量表官方说明 |
| 利生奇珠单抗（Skyrizi） | CD：诱导 **600 mg IV W0/4/8**；维持 **180 mg 或 360 mg SC 自 W12 起每 8 周**（360 是可选剂量之一，不是唯一） | §2.2.3 示例排期与说明书一致，但未写"180 或 360 mg 按医嘱"，也未记"治疗前查肝酶/胆红素、完成适龄疫苗" | 说明书（FDA 标签） |
| 乌帕替尼（Rinvoq） | CD：诱导 **45 mg qd ×12 周**；维持 **15 mg qd**；难治/重症可 30 mg qd | PRD 只在示例里出现"隔天 1 颗"，无诱导/维持剂量口径 | 说明书（FDA 标签） |
| 疫苗与感染筛查 | 进阶治疗前应筛查 HBV/HCV、结核（TST/IGRA）、VZV 等并核对免疫状态；每年流感+肺炎链球菌疫苗；ECCO 2025/2026 更新推荐免疫抑制成人重组带状疱疹疫苗、肺炎球菌新程序、≥60 岁 RSV、COVID 加强 | PRD **全文无"疫苗与感染筛查"记录模块**（检索关键词 疫苗/结核/IGRA/HBV/VZV 均无命中） | 指南（ECCO/区域共识）/ 说明书 |

---

## 1. 粪便钙卫蛋白（FCP）

**结论**：FCP 不存在"唯一参考范围"。分层口径应按来源分别标注：
1. **实验室参考范围**：多数试剂厂商建议 cut-off ≈ **50 µg/g**（不同试剂/医院可不同；本例浙大二院报告单参考值为 `<200 µg/g`）。
2. **灰区**：BIRD 专家共识提出 **100–250 µg/g 建议 3 个月内复测**；>250 µg/g 提示炎症可能性大、值得进一步内镜评估。
3. **指南阈值**：AGA 2023 在"症状缓解且有近期内镜缓解"场景用 **<150 µg/g（+CRP<5 mg/L）排除活动性炎症**；术后低危人群用 **<50 µg/g**。AGA 明确是因"便于落地"统一选了 <150 这一条线，并非 200。
4. **200 µg/g 不能当"唯一参考范围"或"缓解线"**：它既非指南阈值，也不是通用实验室界值；把它当缓解线会让 150–200 区间的持续升高被误标为正常。且 FCP 不是"金标准"——内镜才是（BIRD 共识原文：endoscopy remains the gold standard）。

**引用**
- [AGA Clinical Practice Guideline on the Role of Biomarkers for the Management of Crohn's Disease（Gastroenterology 2023；PDF 全文）](http://socgastro.org.br/novo/wp-content/uploads/2024/02/PIIS0016508523050643.pdf) — 原文（PDF 抽取，单位 µ 显示为 m）："In patients in symptomatic remission, a fecal calprotectin <150 mg/g and normal CRP rules out active inflammation, avoiding endoscopic evaluation for assessment of disease activity."；Recommendation 2："the AGA suggests using fecal calprotectin <150 mg/g and/or CRP <5 mg/L to rule out active inflammation, and avoid routine endoscopic assessment of disease activity. (Conditional recommendation, low to moderate certainty of evidence)"；Recommendation 10（术后低危）："fecal calprotectin <50 mg/g, to avoid routine endoscopic assessment of disease activity." ｜类型：**【指南阈值】**
- [AGA 指南 PubMed 记录（PMID 37981354）](https://pubmed.ncbi.nlm.nih.gov/37981354/) — 同上结论的题录入口（本机访问 PubMed 返回 203/空页，故以 PDF 为准；题录信息可核对）｜类型：**【指南阈值】**
- [BIRD 专家共识：Expert opinion for use of faecal calprotectin in diagnosis and monitoring of IBD（United European Gastroenterol J 2018）](https://pmc.ncbi.nlm.nih.gov/articles/PMC6169045/) — "FC > 250 µg/g identifies patients who are most likely to have intestinal inflammation and justifies further endoscopic examination."；"FC between 100 and 250 µg/g could require a second measurement within three months."；"A cut-off of 50 µg/g is recommended by most test suppliers."；"endoscopy remains the gold standard to assess disease activity and major therapeutic changes are not recommended based on FC alone." ｜类型：**【综述/专家共识】** + 汇总的**【实验室参考范围】**
- [NICE HTG320（原 DG11）：Faecal calprotectin diagnostic tests for inflammatory diseases of the bowel](https://www.nice.org.uk/guidance/htg320/chapter/1-Recommendations) — 推荐只要求"appropriate quality assurance processes and locally agreed care pathways are in place"，**未规定统一 cut-off**；说明阈值由本地实验室/路径决定，不存在"全国统一参考范围" ｜类型：**【指南（流程性）】**
- 本地检验口径（内部证据，非公开来源）：`~/.dsh/skills/crohns-lab-tracker/SKILL.md` 第 50 行 `('FCP', '粪便钙卫蛋白', '<200', lambda v: v >= 200)`，即把浙大二院报告单的 `<200` 直接当作"异常判定阈值" ｜类型：**【实验室参考范围】**（该院报告单参考值；非指南）

**PRD v1.3 修正建议**：§2.1.3 表中把"粪便钙卫蛋白 `<200`"改为分层展示（至少两档：`≤50 阴性 / 50–150 灰区 / >150 提示活动性炎症（AGA 场景）`，并注明"各实验室参考范围不同，按报告单"; 200 仅作为"某院报告参考上限"示例）；删除"肠道炎症金标准"表述，改为"肠道炎症的非侵入性生物标志物（内镜为参考标准）"；删除"200 缓解线"，改为"阈值线按所选口径分层显示，并标注来源（实验室参考范围/AGA 指南）"。

---

## 2. SES-CD（Simple Endoscopic Score for Crohn's Disease）

**结论**：标准评分表的总分上限是 **0–56**，不是 0–60。构成：4 个变量（溃疡大小、溃疡面、受累面、狭窄）× 5 个肠段 × 每项 0–3 分 = 60 分上限，但**狭窄项（narrowings）因"不能通过的狭窄只能被观察到一次"其小计上限为 11 分**（其余三项各 15 分：15+15+15+11=56）。因此文献中 0–60 的说法是把狭窄项也按 15 分计算的算术误写。
分级 **0–2 缓解 / 3–6 轻 / 7–15 中 / ≥16 重** 是文献常用分类（用于展示可以，但应注明"文献常用分级，非原版 SES-CD 验证自带的唯一阈值"）。内镜缓解常用 **SES-CD <3（即 ≤2）**、重度常用 **>15**。

**引用**
- [Janssen/Stelara 儿科 III 期 SAP（ClinicalTrials.gov 公开文档，Table 4 SES-CD 评分表）](https://cdn.clinicaltrials.gov/large-docs/57/NCT04673357/SAP_001.pdf) — "Total 1 + 2 + 3 + 4 = SES-CD (56 max)"；"* The maximum sub-score for narrowings (ie stricturing) is 11 points. The presence of a narrowing that cannot be passed can be only observed once."；三项各 "15 max" ｜类型：**【评分表/方案文件】**（转引 Kerur 2020 标准表）
- [Clinical Usefulness of the MINI Score as a Non-Invasive Index（PMC12692616）](https://pmc.ncbi.nlm.nih.gov/articles/PMC12692616/) — "Depending on the total number of points, endoscopic CD activity was classified as no activity, 0–2 points; mild form, 3–6 points; moderate form, 7–15 points; severe form, ≥16 points." ｜类型：**【综述/临床研究常用分级】**
- [Calprotectin 与 SES-CD 相关性研究（J Korean Med Sci 2026；PMC13574557）](https://pmc.ncbi.nlm.nih.gov/articles/PMC13574557/) — "Severe disease (SES-CD > 15) 61 (39.6)"；"Endoscopic remission (SES-CD < 3) 78 (50.7)" ｜类型：**【研究阈值（与指南口径一致）】**
- [SES-CD 教学材料（NISG，PDF）](https://nisg.no/wp-content/uploads/Crohns-Disease-Simple-Endoscopic-Score-SES-CD.pdf) — "The final score is the sum of four variables – 1.4 x (number of affected segments) and ranges from 0 to 60 points." ｜类型：**【教学材料（0–60 误写的典型来源；该句还把 CDEIS 的 1.4 校正混入 SES-CD）】**——用于说明 0–60 说法的由来，不建议引用其数值。

**PRD v1.3 修正建议（一句话口径）**："SES-CD 按标准评分表记录：4 变量×5 段、每项 0–3，狭窄项小计上限 11，总分 **0–56**；PRD 只存/展示总分与评分表版本，不写死 0–60；分级 0–2/3–6/7–15/≥16 仅作文献常用分类展示，不作诊断结论。"

---

## 3. Limberg 评分（彩色多普勒血流分级）

**结论**：Limberg 是**肠壁血流（充血）**的彩色多普勒半定量分级，不是疾病活动度总分。GETECCU 2021 指南采用 modified Limberg：**0 级 无血流；1 级 1–2 点/cm²（barely visible）；2 级 3–5 点/cm²（moderate）；3 级 >5 点/cm² 或血流延伸至肠壁外（intense）**——即 **0–3 共 4 档**。部分资料/本仓库 Skill 用 I–IV 级，属同一 4 档量表的不同编号（I=无血流…IV=高血流）；**"0–4 级"的写法与指南不符**，若产品沿用 0–4 必须标明所用版本。单独用 Limberg 做"分级趋势"会过度解读：它只是 IBUS-SAS 的加权成分之一（CDS 权重 7），临床判读需结合肠壁厚度（BWT）、肠壁分层（BWS）、炎症脂肪（i-fat）。

**引用**
- [GETECCU 指南：Recommendations on the use of abdominal ultrasound in IBD（Gastroenterol Hepatol 2021;44:158–174，PDF）](https://www.elsevier.es/en-revista-gastroenterologia-hepatologia-english-edition--382-pdf-download-S2444382421000420) — "Vessel density is assessed using the modified Limberg semi-quantitative score, which classifies the degree of wall vascularity from 0 to 3."；Figure 3 图注："Grade 0: no vessels; Grade 1 or barely visible: 1-2 points/cm2; Grade 2 or moderate: 3-5 points/cm2; Grade 3 or intense: >5 points/cm2 or even vessels outside the wall." ｜类型：**【指南（影像判读定义）】**
- [Expert Consensus on IBUS-SAS（J Crohns Colitis 2021；PMC8023841）](https://pmc.ncbi.nlm.nih.gov/articles/PMC8023841/) — 回归系数表："BWT 4.0 … i-fat 14.8 … CDS 6.7 … BWS 4.1"；"Regression coefficients were calculated based on the global activity and severity score from 0 [theoretical no disease] to 100 [theoretical worst ever activity/disease]" ｜类型：**【专家共识】**——说明 Limberg/血流只是综合评分的组成部分。
- [Ultrasound criteria for transmural healing in Crohn's disease: systematic review（PMC13533201）](https://pmc.ncbi.nlm.nih.gov/articles/PMC13533201/) — "Across all studies BWT ≤ 3 mm was the dominant criteria, present in 79% (31/39) of definitions. Complete or near-complete absence of color Doppler flow was featured in 64% (25/39)…"；条目中出现 "Limberg score improvement" 作为**联合**判据 ｜类型：**【综述】**——支持"需与其他参数联合"。

**PRD v1.3 修正建议**：把 Limberg 从"独立分级趋势"改为"超声综合评估"下的一个字段，文案限定为"Limberg 血流分级（0–3，部分资料记 I–IV），需结合肠壁厚度/分层判读，不代表整体活动度"；趋势图仅作同一患者纵向参考，不与 SES-CD/IBUS-SAS 混排为"活动度"。

---

## 4. IBUS-SAS

**结论**：IBUS-SAS = **International Bowel Ultrasound Segmental Activity Score**，由 11 位国际专家 Delphi 共识 + 盲读开发，测**肠段水平的超声活动度**；加权公式 **IBUS-SAS(0–100) = 4·BWT(mm) + 15·i-fat + 7·CDS + 4·BWS**（BWT 肠壁厚度、i-fat 炎症脂肪、CDS 彩色多普勒血流信号、BWS 肠壁分层），文献报告截断值 **23.8（诊断活动）**、**40.0（中重度）**。注意：公式对 BWT 是线性加权，教学示例中 BWT=11 mm 时算得 107，说明"0–100"是理论量程而非硬上限。PRD 写"未支持"过于绝对，应分三层：①字段可录入（原文/数值）；②已做数值化解析/校验；③已做趋势与阈值提示（当前未做）。

**引用**
- [IBUS Advanced Ultrasound Workshop, DDW 2025（IBUS 官方教学 PDF）](https://ibus-group.org/wp-content/uploads/2025/05/1.5._H._Huynh_Scoring.pdf) — "IBUS − SAS (0−100) = 4 · BWT + 15 · i-fat + 7 · CDS + 4 · BWS"；"The optimal cut-off value for diagnosing activity with IBUS-SAS is 23.8, while the optimal cut-off value for diagnosing moderate-to-severe activity is 40.0."；"Deplhi consensus of 11 world experts … Blind reading of 20 studies" ｜类型：**【专家共识/教学材料】**
- [Novak KL et al., J Crohns Colitis 2021;15:609–616（PMC8023841）](https://pmc.ncbi.nlm.nih.gov/articles/PMC8023841/) — 同上回归系数与 "0–100" 理论量程表述 ｜类型：**【专家共识（原始文献）】**
- 同上教学材料结论页 — "These disease scores are reasonable at detecting disease activity especially moderate to severe and remain a research tool … It remains to be determined what are the target scores for treatment response and in what context" ｜类型：**【综述/教学】**——支持 PRD 不要把 IBUS-SAS 写成已确立的诊疗目标。

**PRD v1.3 修正建议**：将 §2.1.4 "IBUS-SAS 未支持"改为分层状态："超声报告可记录 IBUS-SAS 原文/数值（字段已支持）；未做加权计算、阈值提示与趋势；不作为治疗决策依据"。

---

## 5. SIBDQ

**结论**：SIBDQ（Short Inflammatory Bowel Disease Questionnaire）**就是 10 题简版 IBDQ**（Irvine 等开发），覆盖肠道症状、全身症状、情绪、社会功能 4 个方面；**每项 1–7 分 Likert，总分 10–70**，分越高 HRQOL 越好。**未检索到公认的统一界值**（文献常用不同 cutoff 做分组，但不是量表官方阈值）——标注不确定。PRD 若继续用，应改名 SIBDQ 并写明计分，且注明"非 IBDQ-32、无官方界值，仅作内部纵向趋势"。

**引用**
- [Rohatinsky et al., J Can Assoc Gastroenterol 2023;6(3):116–124（PMC10235589）Table 1](https://pmc.ncbi.nlm.nih.gov/articles/PMC10235589/) — "SIBDQ … Measures four aspects of HRQOL on a 7-point Likert scale: bowel symptoms, systemic symptoms, emotional status, and social interactions. Scale scores summed to achieve a score between 10 and 70 with a higher scale score representing a greater perceived HRQOL"（引 Irvine et al.）｜类型：**【综述（量表引用）】**
- 同文 METHODS — 使用 "The Short Inflammatory Bowel Disease Questionnaire (SIBDQ) … ([15])" 作为 HRQOL 主量表 ｜类型：**【综述】**
- 关于界值：本次检索（Europe PMC/PMC 全文）未找到 SIBDQ 的官方 cutoff 声明 ｜类型：**【不确定】**

**PRD v1.3 修正建议**：§2.7.4 条目改为"**SIBDQ（10 题简版 IBDQ）**：1–7 计分、总分 10–70；无公认界值，仅用于同一患者纵向比较"；数据模型加 `instrument=SIBDQ`、`score_min=10`、`score_max=70`。

---

## 6. SF-36

**结论**：
1. **标准条目映射**：PF 10 题（Q3–12）、RP 4 题（Q13–16）、RE 3 题（Q17–19）、VT 4 题（Q23/27/29/31）、MH 5 题（Q24/25/26/28/30）、SF 2 题（Q20/32）、BP 2 题（Q21/22）、GH 5 题（Q1/33/34/35/36），合计 35 题；**第 36 题（健康变化）不计入任何域**。
2. **计分**：条目按各自选项**反向/正向重编码**（如 Q20 的 1→100…5→0，Q32 的 1→0…5→100），使高分=好；每题 0–100，域分=域内条目均值（缺失条目不计），即 **0–100 线性转换**。
3. **PCS/MCS**：需用常模因子加权得到 T 分（美国常模均值 50、SD 10）；**RAND 官方计分说明只给 8 域 0–100，不含 PCS/MCS**，且 RAND 计分与 MOS SF-36 计分不同，官方要求按 RAND 计分时应称 **RAND 36-Item Health Survey 1.0**（不是"SF-36"）。
4. **为什么 App 的"简化 0–4 + 自算域分"不可与标准分对照**：①选项锚点被统一成 0–4，条目重编码规则与标准不同；②域映射不同（本仓库实现为 PF 8 题、RP 5 题、SF 5 题、RE 5 题、GH 1 题等，见 `sf36-standard-scoring.md` S2.2，与标准 10/4/2/5/4/2/3/5 不一致）；③无反向计分（因题干/锚点已改）；④无 PCS/MCS。因此 0–100 数值**不能与文献/SF-36 常模对照**，也不应命名为"SF-36 得分"（SF-36 为注册商标/授权量表；RAND-36 可免费使用）。

**引用**
- [RAND 36-Item Health Survey 1.0 Scoring Instructions（RAND 官方文档镜像，页脚标注 rand.org 原址）](https://cansw.org/wp-content/uploads/2020/03/RAND-36-Scoring-Instructions.pdf) — "all items are scored so that a high score defines a more favorable health state. In addition, each item is scored on a 0 to 100 range…"；Table 2：Physical functioning 10 items / Role limitations due to physical health 4 / Role limitations due to emotional problems 3 / Energy/fatigue 4 / Emotional well-being 5 / Social functioning 2 / Pain 2 / General health 5；"Items that are left blank (missing data) are not taken into account"；"Because the scoring method described here … differs from that of the MOS SF-36, persons using this scoring method should refer to the instrument as RAND 36-Item Health Survey 1.0." ｜类型：**【量表官方计分】**
- [Disease burden of ATTR amyloidosis based on the SF-36 health survey（Cardio-Oncology 2026；PMC13085746）](https://pmc.ncbi.nlm.nih.gov/articles/PMC13085746/) — "Scores are presented using norm-based scoring, where a value of 50 represents the mean of the general U.S. population, with a standard deviation of 10." ｜类型：**【综述】**——PCS/MCS 常模加权口径
- 内部实现证据：[`docs/compose/spec/sf36-standard-scoring.md`](../../docs/compose/spec/sf36-standard-scoring.md) S2.2/S2.3 — "现有选项已统一「分越高越好」（0=很差 … 4=很好），**无需反向计分**"；域映射 PF 题索引 2–9（8 题）、RP 5 题、SF 5 题、RE 5 题、GH 1 题；"不做 PCS/MCS 常模" ｜类型：**【内部实现】**——用于说明与标准不可比的具体原因

**PRD v1.3 修正建议（限定语）**："本 App 的 SF-36 条目为**非授权简化版**（统一 0–4 锚点、域映射与标准 RAND-36 不同、无 PCS/MCS），其 0–100 域分**不可与标准 SF-36/RAND-36 分数或常模对照**，仅用于同一患者内部趋势；界面与导出不得称'标准 SF-36 得分'。"

---

## 7. PHQ-2 / GAD-2

**结论**：PHQ-2 由 PHQ-9 前 2 题组成、GAD-2 由 GAD-7 前 2 题组成（各覆盖过去 2 周核心症状），**每题 0–3 分、总分 0–6**；官方说明明确 **≥3 分为筛查阳性**，阳性应转做完整 PHQ-9/GAD-7（PHQ-4=两者合计 0–12）。**"每月一次"是产品节奏选择，不是指南规定**——可用作轻量筛查记录，但不得替代诊断或作为用药依据。

**引用**
- [PHQ Screeners Instruction Manual（phqscreeners.com 官方 PDF）](https://www.phqscreeners.com/images/sites/g/files/g10016261/f/201412/instructions.pdf) — "These consist of the first two items of the PHQ-9 and GAD-7 respectively … Each ranges from a score of 0 to 6. … the recommended cutpoints for each when used as screeners is a score of 3 or greater."；"For the ultra-brief measures (PHQ-2 and GAD-2), a score of 3 or greater should prompt administration of the full PHQ-9 and/or GAD-7, as well as a clinical interview…" ｜类型：**【量表官方说明（筛查阈值）】**
- [phqscreeners.com 官方站点（量表免费下载页）](https://www.phqscreeners.com/select-screener) — "All PHQ, GAD-7 screeners and translations are downloadable from this website and no permission is required to reproduce, translate, display or distribute them." ｜类型：**【量表官方站点】**——支持产品内使用/翻译的合规性
- （可选对照）PRD 现有 PHQ-9 分档：0–4 无/极轻、5–9 轻、10–14 中、15–19 中重、20–27 重，cutoff ≥10 提示中重度 ｜类型：**【量表官方/文献】**——见 [PMC12829537](https://pmc.ncbi.nlm.nih.gov/articles/PMC12829537/) 所述分档

**PRD v1.3 修正建议**：在 §2.7.4 增加"月度 PHQ-2 + GAD-2（各 0–6，≥3 提示需进一步评估）"，并注明"筛查工具，非诊断；阳性仅提示可与医生沟通或做完整量表"；与 PHQ-9（较长、按需）分层。

---

## 8. 利生奇珠单抗（risankizumab / Skyrizi）克罗恩病

**结论**：FDA 标签（Skyrizi®）CD 适应证：**诱导 600 mg IV，W0/W4/W8（每次输注 ≥1 小时）；维持 180 mg 或 360 mg SC，自 W12 起每 8 周一次**（"Use the lowest effective dosage"）。因此本仓库/Skill 记录的"600 mg IV W0/4/8 → 360 mg SC 自 W12 每 8 周"与说明书一致，但 360 mg 只是两个允许维持剂量之一，PRD 应写"180 或 360 mg（按医嘱）"。标签还要求：治疗前查**肝酶与胆红素**，并**完成适龄疫苗**。

**引用**
- [DailyMed — SKYRIZI (risankizumab-rzaa) 处方信息（SPL，FDA）](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7148c8eb-b39e-e20a-6494-a6df82392858) — "The recommended induction dosage is 600 mg administered by intravenous infusion over at least one hour at Week 0, Week 4, and Week 8. The recommended maintenance dosage is 180 mg or 360 mg administered by subcutaneous injection at Week 12, and every 8 weeks thereafter. Use the lowest effective dosage to maintain therapeutic response." ｜类型：**【说明书】**
- 同上，Dosage and Administration 前置要求 — "For the treatment of moderately to severely active Crohn's disease and ulcerative colitis: Obtain liver enzymes and bilirubin levels prior to initiating treatment with SKYRIZI. … Complete all age-appropriate vaccinations as recommended by current immunization guidelines" ｜类型：**【说明书】**
- （对照）UC 诱导为 1200 mg IV W0/4/8（勿与 CD 混淆）｜类型：**【说明书】**

**PRD v1.3 修正建议**：§2.2.3 示例排期保留 600/360，但补充"维持剂量 180 mg 或 360 mg（以医嘱为准）"；药物字段增加 `induction_dose`/`maintenance_dose`、`pretreatment_screening`（肝酶/胆红素/疫苗）标记，仅记录不判断。

---

## 9. 乌帕替尼（upadacitinib / Rinvoq）克罗恩病

**结论**：FDA 标签 CD：**诱导 45 mg 每日一次 ×12 周；维持 15 mg 每日一次；难治/重症/广泛病变可考虑 30 mg 每日一次**（30 mg 未达应答应停药）；"用最低有效剂量"。与 UC 诱导 8 周不同，PRD 不应把 UC 的 8 周套到 CD。

**引用**
- [DailyMed — RINVOQ (upadacitinib) 处方信息（SPL，FDA）](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2966aec7-2ef0-923c-d8ff-fe1a957bf095) — "Adults: The recommended induction dosage of RINVOQ is 45 mg once daily for 12 weeks. The recommended maintenance dosage of RINVOQ is 15 mg once daily. A maintenance dosage of 30 mg once daily may be considered for patients with refractory, severe, or extensive disease. Discontinue RINVOQ if an adequate therapeutic response is not achieved with the 30 mg dosage." ｜类型：**【说明书】**
- 同上 §2.7 — "The recommended dosage of RINVOQ for maintenance treatment is 15 mg once daily. A dosage of 30 mg once daily may be considered…" ｜类型：**【说明书】**
- 同上 UC 章节 — "The recommended induction dosage … is 45 mg once daily for 8 weeks"（与 CD 12 周区分）｜类型：**【说明书】**

**PRD v1.3 修正建议**：药物字典中乌帕替尼增加"CD 诱导 45 mg×12 周 / 维持 15 mg（可 30 mg）"字段；现有"隔天 1 颗"仅作为患者实际记录值，不写进方案模板。

---

## 10. 免疫抑制 IBD 患者的疫苗与感染筛查

**结论**：指南一致要求"进阶治疗/免疫抑制前做感染筛查 + 核对疫苗状态"，这解释了 PRD 为什么应有独立的"疫苗与感染筛查"**记录**模块（只记录项目/日期/剂次/结果，不做是否接种的判断）：
- **筛查**：HBV/HCV 血清学、结核（TST 和/或 IGRA，必要时胸片）为强制项；HIV 在风险人群考虑；VZV（及 MMR）免疫状态不明时查血清学；CMV/EBV 视情况。
- **疫苗**：每年流感 + 肺炎链球菌为 IBD 常规；ECCO 2025/2026 更新强调免疫抑制成人**重组带状疱疹疫苗**、肺炎球菌新程序、≥60 岁 RSV、COVID-19 加强。
- **说明书层面**：Skyrizi 标签要求"完成适龄疫苗"。

**引用**
- [Second United Arab Emirates consensus guidance on the diagnosis and management of IBD（World J Gastroenterol 2025;31(35):109882）](https://www.f6publishing.com/Forms/Main/DownloadFile.aspx?type=m&typeid=4&id=109882) — Statement 94："A comprehensive pre-advanced therapy safety screening (that includes hepatitis B, hepatitis C, and tuberculosis) should be performed before initiating advanced therapy to minimize the risk of opportunistic infections…(evidence level: 3b; strength of recommendation: Strong; consensus agreement: 100%)."；"Tuberculosis screening with tuberculin skin test and/or interferon-gamma release assay, and a chest X-ray if needed, is mandatory before starting immunosuppressive therapy."；"annual influenza and pneumococcal vaccines as recommended for IBD patients"；"If measles-mumps-rubella or varicella-zoster virus immunity is uncertain, serology should be checked"；"Cytomegalovirus and Epstein-Barr virus serologies testing maybe performed if indicated." ｜类型：**【指南（区域共识）】**
- [ECCO 官方通稿：New ECCO Guidelines on Opportunistic Infections in IBD – 2025 Update（ECCO News, 2025-12-17）](https://ecco-ibd.eu/publications/news/issues/2025/volume-20-issue-4/new-ecco-guidelines-on-opportunistic-infections-in-ibd-2025-update) — "…translating this into a strong recommendation for recombinant zoster vaccine for all adult IBD patients on immunosuppression. Pneumococcal schedules have been updated to incorporate newer conjugate vaccines, and for the first time the guideline includes recommendations on respiratory syncytial virus vaccination in patients aged ≥60 years and on COVID-19 booster strategies in IBD…" ｜类型：**【指南（ECCO 官方摘要）】**
- [DailyMed — SKYRIZI 标签（同上）](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7148c8eb-b39e-e20a-6494-a6df82392858) — "Complete all age-appropriate vaccinations as recommended by current immunization guidelines" ｜类型：**【说明书】**
- （背景）[ECCO Guidelines 目录页](https://ecco-ibd.eu/publications/guidelines) — "Prevention and management of Opportunistic Infections | 2026" ｜类型：**【指南目录】**——证实现行版本存在

**PRD v1.3 修正建议**：新增 §"疫苗与感染筛查记录"：项目清单（HBV/HCV、结核 IGRA/TST、VZV、EBV/CMV、流感、肺炎链球菌、带状疱疹、COVID-19）、字段（项目/日期/结果/剂次/来源报告）、文案"仅记录，不判断是否需要接种或治疗，具体请咨询医生"；并在"就诊摘要"中作为可勾选章节展示。

---

## 11. 可直接写进 PRD v1.3 的一句话口径（汇总）

1. **FCP**："粪便钙卫蛋白按报告单参考范围展示；参考分层：≤50/50–150/>150 µg/g（AGA 场景阈值），200 µg/g 不是通用缓解线；异常提示仅建议与医生沟通，不构成诊断。"
2. **SES-CD**："SES-CD 按标准评分表记录（4 变量×5 段，每项 0–3，狭窄项上限 11，总分 0–56）；分级 0–2/3–6/7–15/≥16 为文献常用分类，仅作展示。"
3. **Limberg**："Limberg 为彩色多普勒肠壁血流分级（0–3，部分资料记 I–IV），需结合肠壁厚度/分层判读，不代表整体活动度。"
4. **IBUS-SAS**："IBUS-SAS（International Bowel Ultrasound Segmental Activity Score）为 0–100 加权超声评分（4·BWT+15·i-fat+7·CDS+4·BWS）；当前仅支持记录原文/数值，未做加权计算与阈值提示。"
5. **SIBDQ**："SIBDQ 为 10 题简版 IBDQ，1–7 计分、总分 10–70，无公认界值，仅作同一患者纵向趋势。"
6. **SF-36**："本 App 的 SF-36 为非授权简化版（统一 0–4 锚点、域映射与标准不同、无 PCS/MCS），0–100 域分不可与标准 SF-36/RAND-36 分数对照，仅作内部趋势。"
7. **PHQ-2/GAD-2**："PHQ-2/GAD-2 各 2 题、0–6 分，≥3 提示需进一步评估；月度记录为产品节奏，非指南要求，筛查结果不构成诊断。"
8. **利生奇珠单抗**："CD 诱导 600 mg IV W0/4/8；维持 180 mg 或 360 mg SC 自 W12 起每 8 周（以医嘱为准）。"
9. **乌帕替尼**："CD 诱导 45 mg qd×12 周；维持 15 mg qd（难治/重症可 30 mg qd，以医嘱为准）。"
10. **疫苗与感染筛查**："提供疫苗与感染筛查记录（HBV/HCV、结核 IGRA/TST、VZV、EBV/CMV、流感、肺炎链球菌等），仅记录，不判断是否接种或治疗。"

---

## 12. 证据不足 / 不确定清单（PRD 引用时须保留不确定性）

| 事项 | 状态 | 处理建议 |
|---|---|---|
| Limberg "0–4 级" | **不确定**：GETECCU 指南为 0–3；Skill 用 I–IV（4 档）。"0–4"未见一手指南依据 | PRD 写"0–3（部分资料记 I–IV）"，并标注量表来源；不要写"0–4" |
| SES-CD 分级 3–6/7–15 | **文献常用分类**，未在原版 SES-CD 验证论文中检索到"官方分级"表述（原版以总分+阈值使用） | 标注"文献常用分类，非原版官方分级"；PRD 不据此给患者下"轻度/中度"结论 |
| SIBDQ 界值 | **不确定**：未找到官方 cutoff | 不设界值，仅显示总分与趋势 |
| PHQ-2/GAD-2 月度频率 | **无指南依据**（官方只说 ≥3 阳性转完整量表） | 标注"产品节奏，非指南要求" |
| IBUS-SAS 0–100 上限 | 公式为线性加权，BWT=11 mm 示例算得 107；原始文献称"0–100 理论量程" | PRD 不写"满分 100"，写"理论量程 0–100，实际可超" |
| FCP 各实验室界值 | **不通用**（试剂/方法不同；本机报告为 <200） | 按报告单参考范围展示 + 标注指南阈值，二者分列，不合并成一条"参考范围" |
| SF-36 授权/命名 | SF-36 为注册商标/授权量表；RAND-36 免费但计分不同 | 产品内命名"RAND-36（简化版）"或"生活质量自评（非标准量表）"，避免商标与可比性风险 |

---

## 13. 检索说明与限制

- 检索日期 2026-11-02；优先顺序：监管标签（DailyMed/FDA）→ 学会指南（AGA/ECCO/GETECCU/NICE）→ 量表官方（RAND、phqscreeners）→ PMC 综述。
- 部分站点在本机网络不可达（rand.org、gastrojournal.org、PubMed 摘要页、cdisc wiki 的 SF-36v2 手册），已改用**可访问的官方文档镜像/全文 PDF**并保留原始 URL 标注；未使用任何无法打开页面的内容。
- 本文所有"建议 PRD 采用的表述"只涉及**记录与展示口径**，不涉及诊断、治疗或接种建议；临床判断仍由医生完成。
- 若 PRD v1.3 需要引用原始论文（Daperno 2004 SES-CD、Irvine 1996 SIBDQ、Limberg 1999、Ware 1992 SF-36），建议由法务/医学顾问补齐授权与 DOI 后再写入正式文档。
