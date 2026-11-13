# 会话工作清单（Backlog）

> **状态硬性要求**：每开始一项工作，必须先把本清单对应项改为 `进行中`；完成后改为 `已完成`；受阻改为 `阻塞` 并写明原因。禁止只改任务面板、不改本文件。同步规则见 [README · 工作清单](../README.zh-CN.md#工作清单状态规则)。
>
> **二次验证规则**：每次写完代码必须二次验 bug，通过后才可标「已完成」。见 [README · 二次验证规则](../README.zh-CN.md#二次验证规则强制)。

**状态取值**：`待办` · `进行中` · `阻塞` · `已完成` · `已取消`

**创建**：2026-09 对照 v0.1.0 代码现状盘点 · **基线**：本地优先 MVP 已落地，下列为未完成项。

---

## P1 · 真机验收 + 推送真发（FCM / 厂商 / iOS）

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T2.1 | 接 `firebase_messaging` + 真 FCM token 上报 | 阻塞 | 代码就绪 · **暂无法提供 Firebase 凭据**（[firebase-setup](firebase-setup.md)） |
| T2.2 | 配置 `FCM_*` 并验证 push 真发 | 阻塞 | 同上 · 待凭据后验证 |
| T2.3 | 国内厂商推送通道接入（按需） | 待办 | 小米/华为等厂商 token 上报，离线可唤醒 |
| T2.4 | Android 真机验收 | 待办 | 对照 [device-test-checklist](device-test-checklist.md) 主路径全过 |
| T2.5 | iOS 真机验收 + APNs | 待办 | 冷启动/离线/解析/注射提醒 + APNs 送达 |

## P2 · 微信小程序 MVP（Taro）

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T3.1 | Taro 脚手架 + `api-client` / 共享类型接入 | 已完成 | 可编译预览，类型与 domain-types 一致 · `apps/miniapp` + `packages/api-client` |
| T3.2 | MVP 四页：检验查看 / 打卡 / 注射提醒 / 摘要分享 | 已完成 | 四页可用，不做 PDF 解析 / 独立排便 / 年度报告 |
| T3.3 | 微信登录 + 订阅消息推送 | 进行中 | 非登录墙 · `wx_auth.ts` 已实现；**模板 ID / 微信 appid 待配** |

## P3 · PC Web 四项待完成

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T4.1 | React+Vite Web 脚手架 + domain-types 对齐 | 已完成 | `apps/web` Vite+React+Router+ECharts |
| T4.2 | 批量 PDF 解析（多文件上传与确认） | 已完成 | 真上传链路：presign→PUT→enqueue→轮询→confirm（用完即删）· 见 T4.2b |
| T4.3 | 完整趋势图表（多指标叠加、时间范围） | 已完成 | ECharts 多指标 + 近3月/1年/全部 |
| T4.4 | 手术/检查完整编辑表单 | 已完成 | 所见/结论/备注可编辑增删改 |
| T4.5 | 数据/报告导出 | 已完成 | JSON/CSV · 导入 · 摘要打印 |

## P4 · 解析后删除云端原件 + Phase0 收尾

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T5.1 | API/存储：解析完成后删除云端原件 | 已完成 | confirm 后（或用户勾选后）云端 PDF 删除 · `sourceDeleted` + `delete-source` + `files/object` DELETE |
| T5.2 | App：解析后删除开关 + 「用完即删」文案 | 已完成 | 解析完成后自动删原件；同意弹窗写明「用完即删」 |
| T5.3 | local-first Phase0 勾选 A/B/C/D 与同步模型 | 已完成 | A/B/C/D + E2E 密文 + 无登录墙 · 书面冻结 2026-09 |

## P5 · Skill 社区 / 医生端 / 年度报告 / V2 扩展

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T6.1 | Skill 社区（匿名模板发布 / 评分 / 协作更新） | 已完成 | C1–C4：community 会话 + 发布脱敏 + 评分 + 协作升版 + Web 入口 · 见 [t61-skill-community](compose/spec/t61-skill-community.md) |
| T6.2 | 医生端 Web + 患者扫码授权（DEK 再包裹） | 已完成 | M1–M4：医生账号/Grant/只读视图/建议/审计/收回 · App 侧确认与建议 UI 为本地骨架 · 见 [t62-doctor-web](compose/spec/t62-doctor-web.md) |
| T6.3 | 年度报告（PRD V1.5） | 已完成 | 按年生成概览/用药 + 分享导出 |
| T6.4 | V2 扩展：饮食 / 药物评价 / 同城病友 / AI 分析 | 已完成 | 四轨子包 D1–D4 均已交付（勾选历史 2026-09 D1–D4；P0 验收 F1 更正状态）· 见 [t64-v2-expansion](compose/spec/t64-v2-expansion.md) |
| G1 | 疾病活动度仪表盘（状态灯/Limberg/SES-CD/倒计时） | 已完成 | PRD §2.6.1 · V1.5 |
| G2 | 症状日记补全 + 日历热力 + 快捷模板 | 已完成 | PRD §2.7.1 · 溃疡/关节痛/自定义 · V1.5 |
| G3 | 年报：补齐原版设计（自动生成/同比/检查手术汇总） | 已完成 | PRD §2.6.2 · 默认最近完整年自动构建 + 同比 + 检查手术汇总 |
| G4 | 睡眠/压力每日打卡 | 已完成 | PRD §4.2.2 App 功能表 |
| G5 | PC Excel 导出 + Skill 模板管理表单 | 已完成 | PRD §4.2.4 · V1.5 |
| G6 | 食物-排便关联分析入口 | 已完成 | 食物标签日志 food_logs v7 + 腹泻/便血关联观察页「食物与排便」· 非因果仅供参考 |
| G7 | 标准 SF-36 计分（8 维 0–100） | 已完成 | 并行标准分：保留简化合计 + 8 维 0–100（`sf36_scoring.dart`）· 2026-09 |

## P6 · 可用性（PRD 4.4）

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T7.1 | 大字体模式 + 简洁模式 | 已完成 | 1.25× 字号 · 简洁隐藏隐私条 · 设置开关 |
| T7.2 | 中英文切换（i18n） | 已完成 | 中/英切换 + 设置页选择 · 核心文案词典 |
| T7.3 | SF-36 量表补齐 | 已完成 | 36 题 + 五级选项 · 与 PHQ-9/IBDQ/MiniQoL 并列 |

## P7 · 诊断（local-first D 类）

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T8.1 | 崩溃/性能上报可选开关（默认关） | 已完成 | 设置可开关 · 默认关不上传 · analyze 清零 |

---

## P8 · Phase 0/1 路线计划登记（2026-10 · 任务号 T0–T20 / D1–D4）

> **命名注意**：本节任务号为 **2026-10 路线编号**（T0–T20、D1–D4），与上文 2026-09 遗留的 T2.x/T3.x/T8.1 及 D1–D4（V2.0 扩展四轨，已完成）**不是同一批任务**。
> **执行纪律**：每任务独立分支/独立 commit；只执行用户点名的任务号；数据模型变更必须带迁移/兼容方案；不伪造推送/真机/合规验证；不实现全慢病与 G0 前的新病种/疾病包业务代码。
> **2026-10-26 裁决记录**：① T0.1 先修 CI YAML；② 维持 main 开工（`feature/app-community-wiring` 暂不合并，冲突时 rebase 处理）；③ T1 历史数据按「迁移置空+标记+UI 提示，不静默覆盖」；④ T2 旧 source 数据**不回填**；⑤ T4/T6 统一提醒配置结构；⑥ T5 按软件工程规范处理 scope 边界与错误态；⑦ 本计划登记入册。

### P8.1 · P0 夯实（当前执行）

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T0 | 仓库基线扫描（不改代码） | 已完成 | 扫描报告输出：模块/命令/缺陷定位/任务拆分/风险与确认项 |
| T0.1 | 修复 ci.yml YAML 缩进（先决） | 已完成 | YAML 可解析、步骤语义不变 · `259ec34` → `460758a` |
| T0.2 | Phase 0/1 计划登记入 worklist | 已完成 | 本节入库（P8.1–P8.4） |
| T0.3 | 项目级软件工程强制约束落盘 | 已完成 | 用户点名最高优先级；约束全文原样入库 `docs/engineering-constraints.md`，声明项目级生效 |
| T1 | 修复症状日记 bloating 缺陷 | 已完成 | 腹胀独立录入/展示/保存；历史数据迁移置空+标记（不静默覆盖）；回归测试；迁移策略说明 · 库 v9→v10 · `fix/phase0-t1-bloating` |
| T1.1 | T1 审阅修复：修复标记清除语义改 B + v10 补偿脚本 | 已完成 | 裁决「问题1 B」：仅实际录入腹胀才解除标记；关态保存写 null；补 `docs/migrations/local-db-v10-compensation.sql`（幂等）· `task/t1.1-bloat-flag-semantics` |
| T1.2 | T1 审阅修复：疲劳开关关闭不残留滑块旧值 | 已完成 | 裁决「问题5 立疲劳小任务」：关态保存写 null；新增 `checkin_fatigue_ui_test` 回归 · `task/t1.2-fatigue-toggle-fix` |
| T0.4 | 依赖安全治理（CI 门禁修复） | 已完成 | 裁决「T0.4 开工，2a，3a」：overrides 治本生产链 high+critical（--prod 门禁清零）；dev 链 patch 级修复；遗留项与 swiper 验证 BLOCKED 记录于 docs/dependency-audit-notes.md · `task/t0.4-dependency-audit` |
| T0.4b | 解除 joi 新增 high 公告导致的基线红（2026-11-13） | 已完成 | overrides 定向提升 `joi` 17.13.8→17.13.9（仅补丁级）；`pnpm audit --prod --audit-level=high` 0 high/critical、15 moderate；记录见 docs/dependency-audit-notes.md · `task/t0.4b-joi-audit` |
| T0.5 | 修复 miniapp 构建 + swiper 限期集成验证 | 已完成 | 裁决「点名 T0.5；swiper 先保留限期验证」：补 babel.config.js + babel-preset-taro + 工作区 TS loader；build:weapp 编译成功，swiper 12.2.0 进产物验证通过；运行时验证随真机验收 · `task/t0.5-miniapp-build-fix` |
| T2 | 修复检验来源标记失真 | 已完成 | confirm 按任务真实引擎写 source（skill\|ai）；App 三档标记；旧数据不回填（裁决④）；smoke:parse-source 9 断言 + 迁移行为级探针 + flutter 111 全过 · 证据 docs/audit-evidence/t2-lab-source.md · `task/t2-lab-source-accuracy` |
| T0.6 | 优先修复红 CI：AuthModule DI 接线（R0.13 遗留） | 已完成 | 裁决「CI 红优先修复」：TypeOrmModule.forFeature 补 DevicePubKeyEntity；启动探针证实 DI 恢复；推送后 CI + Fullstack E2E **双绿** · `task/t0.6-auth-di-fix` |
| T3 | App 本地 Skill 缓存可读/可命中/可清理 | 已完成 | txt 报告本地快速通道（全命中才走本地、未命中回落云端）；formatVersion 失效；clear/clearAll+设置页清理入口；不改服务端契约；flutter 123 全过 · 证据 docs/audit-evidence/t3-local-skill-cache.md · `task/t3-local-skill-cache` |
| T4 | 注射提醒提前天数可配置 | 已完成 | 默认 {3} 兼容；ReminderPrefs 持久化（归一化/损坏回退）；调度读配置多提前量（0/1/2/3/7）；设置页多选入口+保存即重排；调度时刻纯函数测试 · 证据 docs/audit-evidence/t4-injection-lead-config.md · `task/t4-injection-lead-config` |
| T5 | 医生端患者侧建议/审计接真实 API | 已完成 | 授权/建议/审计接 /doctor-grants/mine + /doctor-patient/*；修 revoke 传 grantId；空态/错误降级/本地未同步诚实标注；服务端零改动（scope 边界核实）；新增 6 用例，flutter 137 全过 · 证据 docs/audit-evidence/t5-my-doctors-api.md · `task/t5-my-doctors-api` |
| T6 | 提醒体系补全（用药/复查/当天证件） | 已完成 | 三类提醒（注射 lead=0 当天证件档/用药每日默认关/复查自定义）可创建取消；ReminderScheduler 统一重排；文案全脱敏（禁词表测试固化）；T4 移交两项已处置 · 证据 docs/audit-evidence/t6-reminder-system.md · `task/t6-reminder-system` |
| T7 | 合规与安全前置 | 已完成 | DisclaimerFooter×5 页（非诊断/非治疗）；DPIA+知情同意模板入 docs/compliance（法务 BLOCKED 如实标注）；security-checklist 30 项 · 证据 docs/audit-evidence/t7-compliance-security.md · `task/t7-compliance-security` |
| F2 | PRD v1.2 刷新（P0 核对） | 已完成 | 中英两版 V1.2（保留 v1.0/v1.1）：T1–T7 实现状态逐节更正、§7 遗留待办刷新、附录 V1.1→V1.2 修订 9 条 · `task/prd-v1.2-refresh` |

### P8.2 · P1 夯实（G0 前，按用户指定顺序领取，未点名不开工）

| ID | 任务 | 状态 |
|----|------|------|
| T8 | App 趋势增强：多指标叠加/3M/6M/1Y/全部/用药节点/**分层阈值线（≤50/50–150/>150，见 V13-04）** | 待办 |
| T9 | 时间线增强：疾病/不良反应事件、点击详情、年/月缩放、PDF 导出 | 待办 |
| T10 | 导出补全：就诊摘要/时间线/年报 PDF（DOCX 仅评估不实现） | 待办 |
| T11 | 注射排期夯实：诱导/维持双频率、实际日期、**nextAppointment + 医嘱优先；「延迟顺延」已撤销（见 V13-20/V13-35）** | 待办 |
| T12 | 副作用记录 App UI（接现有 API） | 待办 |
| T13 | 检查/手术服务端化（**检查部分=V13-18 已并入清单；手术部分仍待点名**；附件仅评估） | 待办 |
| T14 | Flare 夯实：体温字段/发热条件、评估持久化、摘要复制 | 待办 |
| T15 | i18n 中英文界面生效 + 简洁模式真正精简 | 待办 |
| T16 | 跨端同步升级：记录级去重合并、Web↔App 互通、防重复恢复 | 待办 |
| T17 | 相机拍照上传（保留文件选择） | 待办 |
| T18 | 年度报告增强：年度指标趋势图、Web 年报只读/导出 | 待办 |
| T19 | 解析 Skill 夯实（**已拆入 V13-10/11/25/26**）：check_fn 统一异常判定、multiline 执行、accuracy 统计口径 | 待办 |
| T20 | 小程序订阅消息模板接入 | 阻塞（缺微信 appid/模板 ID，见 P8.4） |
| T21 | dev 工具链升级（Taro/Vite/webpack 链）+ 门禁收紧 | 待办 | 裁决（2026-10-26）：**P1 之后执行**；消化 docs/dependency-audit-notes.md 遗留 11 项后，CI 门禁收紧回全量 `pnpm audit --audit-level=high` |

### P8.3 · Phase 1 设计文档（G0 通过后执行；只写 docs，不写业务代码）

| ID | 任务 | 状态 |
|----|------|------|
| D1（Phase1） | 疾病包 schema v1（指标面板/症状/量表/预警/注射协议/报告模板/医生视图） | 待办 |
| D2（Phase1） | 病种 A 决策矩阵（银屑病/PsA vs RA/AS）+ 临床顾问问题清单 | 待办 |
| D3（Phase1） | 生物制剂横切模块接口草案（双频率/顺延/复查/感染与不良反应/依从性） | 待办 |
| D4（Phase1） | 合规/SaMD 初评问题清单 | 待办 |

### P8.4 · BLOCKED（凭据/真机/法务；不伪造验证结果）

| 事项 | 涉及任务 | 原因 / 解除条件 |
|------|---------|----------------|
| FCM 真发 / 厂商通道 / iOS APNs | T4/T6/T20 及推送相关 | 缺 Firebase 凭据与真机；解除后按 docs/firebase-setup.md 验证并留记录 |
| 微信 appid / 订阅消息模板 ID | T20 | 待外部配置 |
| DPIA / 知情同意法务审核 | T7 | 需法务确认（文档模板先行入库） |
| Android/iOS 真机验收 | T4/T6 | 需设备；按 docs/device-test-checklist.md 执行 |

### P8.5 · PRD v1.3 对齐（Skill v1.4.1；2026-11-02 登记）

> 详细任务、批次、依赖与可判定验收见 [PRD v1.3 工作清单](PRD-v1.3-工作清单.md)（44 项；P0 23 / P1 18 / P2 3；含 2026-11-02 用户补充的注射偏差理由 V13-44，可选填）。本节只做状态登记，验收标准以该文件同名行为准；状态变更须同时回写本表与清单。
> 执行纪律：批0 文档与口径 → 批1 数据模型与指标字典（**阻塞批2/3/4**）→ 批2 解析能力 → 批3 模块补全 → 批4 规则与呈现。

| ID | 任务 | 状态 | 验收（摘要） |
|---|---|---|---|
| V13-01 | 全局边界与文案禁令（PRD 已完成，剩 5 个解读页回指） | 待办 | 5 页回指 §1.5；UI 禁词 0 命中 |
| V13-02 | 文档头五态图例 + 修订清单 + §4.2.6 + §7（PRD 文本） | 已完成 | v1.3 已含五态图例、21 条修订、矩阵增 10 行、§7 增 7 组 |
| V13-03 | 附录 B Skill v1.4.1 能力映射表 | 已完成 | 16 行映射在位，版本号可追溯 |
| V13-04 | FCP 分层参考 + 阈值线纠偏 | 待办 | ≤50/50–150/>150；「200 缓解线」0 命中；阈值常量 1 处 |
| V13-05 | SF-36 可比性禁令与 UI 命名 | 待办 | 「SF-36 得分」0 命中；量表页有禁令 |
| V13-06 | 简版 IBDQ 命名与总分断言（非 SIBDQ） | 待办 | UI 标「自定义」；单测 10–50 |
| V13-07 | 指标字典（核心 14 + 可选 26） | 待办 | 字典行数 14/26；录入与趋势同源 |
| V13-08 | 检验长表 → 宽表（只增不删） | 待办 | 1 报告 = long N 行 + wide 1 行；新指标自动加列 |
| V13-09 | 参考范围来源优先级（pdf/mapping） | 待办 | PDF 优先，缺省回退并标来源 |
| V13-10 | 值语义（运算符/定性原文） | 待办 | 「>1800」原样展示、不做数值比较 |
| V13-11 | 解析追溯字段（confidence/aliases）+ accuracy 口径 | 待办 | 可查置信度/别名；无样本显示「暂无」 |
| V13-12 | activity_score 三拆 + SES-CD 0–56 口径 | 待办 | 56 通过/57 标异常；旧数据不报错 |
| V13-13 | 超声综合评估归并（Limberg/IBUS-SAS） | 待办 | 无「Limberg 好转/加重」；三档状态在位 |
| V13-14 | 检查类型六值枚举 + 兼容映射 | 待办 | 旧值映射可查；统计无「未知」 |
| V13-15 | 待核对队列（pending/manual_fixed） | 待办 | 失败进队列；补齐移出；重复失败合并不增行 |
| V13-16 | 已处理 PDF 清单（五状态） | 待办 | 删原件后清单可查；五状态可构造 |
| V13-17 | 去重键（日期+项目 / 日期+类型） | 待办 | 重复上传不新增，落 skipped_duplicate |
| V13-18 | Examination 服务端化 + 报告路径策略 | 待办 | 服务端可读同一记录；路径可跳转 |
| V13-19 | SymptomDiary 补体重/发热/急性加重/夜间症状 | 待办 | 旧数据 null 不报错；迁移幂等 |
| V13-20 | Injection 加 nextAppointment/scheduleRule/偏差字段 | 待办 | 预约优先；冲突只提示不改日期；偏差原因可选见 V13-44 |
| V13-21 | 记录型实体 schema（就诊/疫苗/营养/心理） | 待办 | 5 实体可读写；升级不丢数据 |
| V13-22 | MedicationChange 七类 + monitoring 频率枚举 | 待办 | 七类可写入时间轴；as_directed 不逾期 |
| V13-23 | 统一 TimelineEvent 表 + 排序权重 | 待办 | 九类可见；近 12 个月；权重单测 |
| V13-24 | 检验日期四层优先级 + dateSource | 待办 | 四类样本各 3 例命中；无日期进队列 |
| V13-25 | 指标名子串误匹配排除规则 | 待办 | 8 例冲突样本全对 |
| V13-26 | 病案号等非检验数值过滤 | 待办 | 13070186 不入 items |
| V13-27 | 检查解析 + 档案产品化（含 L49 口径修正） | 待办 | 3 项目合并 1 条；失败进队列；L49 改口径 |
| V13-28 | 症状补录界面（体重/发热/急性加重/夜间症状） | 待办 | 可录入回显；体温越界拒绝 |
| V13-29 | 用药监测清单模块 | 待办 | 7 频率可建；as_directed 无逾期标记 |
| V13-30 | 用药变更史模块（七类） | 待办 | 剂量调整生成 dose_change；停药必填原因 |
| V13-31 | 就诊/住院/急诊模块 | 待办 | 三类各建 1 条并进时间轴 |
| V13-32 | 疫苗与感染筛查模块 | 待办 | 项目/剂次/结果可录；无接种建议文案 |
| V13-33 | 营养状态模块（体重/BMI/特殊饮食） | 待办 | BMI 自动算不可改；营养检验不双写 |
| V13-34 | 心理轻量记录（PHQ-2/GAD-2） | 待办 | 可只填轻量档；提示可关闭 |
| V13-35 | 注射排期纠偏（服务端 complete） | 待办 | 默认 complete 后续日期不变 |
| V13-36 | 预警规则表（10 类） | 待办 | 10 类各有样本与期望输出 |
| V13-37 | 待办中心 | 待办 | 命中生成、完成留痕、按事件去重 |
| V13-38 | 统一时间轴呈现 | 待办 | 九类渲染；默认近 12 个月 |
| V13-39 | 活动度与量表呈现口径 | 待办 | 量表默认折叠；SF-36/IBDQ 标签合规 |
| V13-40 | 预警与解读文案去建议化 | 待办 | UI 建议动词 0 命中；5 页有边界声明 |
| V13-41 | 数据完整性自检（11 项） | 待办 | 11 项三态输出；失败有修复入口 |
| V13-42 | 备份与导出目录约定 | 待办 | 目录命名与示例；无 PDF/DOCX 承诺 |
| V13-43 | 英文版 PRD v1.3 翻译 | 待办 | 中英节数一致、关键口径逐条对应 |
| V13-44 | 注射偏差理由字段与偏差天数（可选填写，实际≠计划≥1 天） | 待办 | 偏差天数计算正确；原因可选不阻断；不改后续排期 |

---

## 建议开工顺序

1. **T2.1 → T2.2**（推送真发闭环）∥ **T5.1**（隐私承诺，改动面小）
2. **T3.1**（小程序从 0 到 1）
3. 其余按 P3 → P4 收尾 → P5/P6/P7
4. **PRD v1.3 对齐**（P8.5）按批0 → 批1 → 批2 → 批3 → 批4 串行；批1 数据模型阻塞后续批次

## 勾选历史

| 日期 | ID | 状态变更 | 备注 |
|------|-----|----------|------|
| 2026-09 | T5.1/T5.2 | 已完成 | 用完即删：storage.delete + sourceDeleted + App 自动删 |
| 2026-09 | T5.3 | 已完成 | Phase0 A/B/C/D + E2E 密文 + 无登录墙 |
| 2026-09 | T7.1–T7.3 | 已完成 | 大字体/简洁 · 中英 i18n · SF-36 |
| 2026-09 | T6.3 | 已完成 | 年度报告生成 + 分享 |
| 2026-09 | T4.1–T4.5 | 已完成 | PC Web 四页（T4.2 上传为模拟，见 T4.2b） |
| 2026-09 | T3.1/T3.2 | 已完成 | 小程序脚手架 + MVP 四页 |
| 2026-09 | T2.1/T2.2 | 阻塞 | 缺 Firebase 凭据 |
| 2026-09 | T3.3 | 进行中 | 差微信 appid/模板 ID |
| 2026-09 | T9 | 已完成 | 代码审阅：修 IDOR + FCM API 误用 + 死代码 |
| 2026-09 | T13 | 已完成 | 二次验证排查：Flutter 0 error，修 6 处编译/结构 bug |
| 2026-09 | T21 | 已完成 | T2.8 Widget UI 回归全过（settings_a11y_test 新增） |
| 2026-09 | T9a | 已完成 | CI 修复：pnpm-lock 同步（frozen-lockfile 失败根因）· `37bf276` |
| 2026-09 | G1–G5 | 已完成 | prd-v15-gaps：库 v6 / 打卡补全+热力+模板 / 活动度卡 / 年报同比 / Web Excel+Skill 表单 |
| 2026-09 | T2.7 | 已完成 | web tsc 归零；根因 api-client 重复方法已清 |
| 2026-09 | docs-align | 已完成 | 文档对齐：local-first status→delivered + Phase 勾选；architecture T6 回勾；prd-gap-audit T3 标注由 prd-v15-gaps 接管 |
| 2026-09 | G7 | 已完成 | SF-36 并行标准 8 维 0–100 + 简化合计；域映射/域分纯函数 + UI 预览/历史 |
| 2026-09 | D-group | 已完成 | 8 维趋势卡（sf36_trend + 量表页）；无网冒烟自动化代理 offline_smoke_test |
| 2026-09 | G6 | 已完成 | 食物日志 v7 + 食物×排便关联分析入口（观察用，非因果） |
| 2026-09 | t61/t62-breakdown | 已完成 | T6.1 拆 C1–C4、T6.2 拆 M1–M4；worklist 指向两份 spec |
| 2026-09 | T6.1 | 已完成 | Skill 社区 C1–C4（脱敏/发布/评分/协作/Web）· 审阅修 critical 后 APPROVE |
| 2026-09 | D4 | 已完成 | AI/规则分析：趋势纯函数 + 异常规则 + 用药前后对比 + 分析入口页 |
| 2026-09 | D1 | 已完成 | 饮食：词典/食谱/营养 v8 |
| 2026-09 | D2 | 已完成 | 药物评价：本地+服务端聚合+白名单 |
| 2026-09 | D3 | 已完成 | 同城：档案/指南/匿名帖+无位置隐私 | 饮食：词典/食谱/营养粗记 v8 + 汇总条 |
| 2026-10 | R0.1–R0.3 | 已完成 | 代码审查修复：CI 全量 flutter test；patients IDOR + 医生审核 token 收紧；检验数据源收敛 + 一致性守卫 |
| 2026-10 | R0.4/R0.5 | 已完成 | 装 git/node20/pnpm9/python3.12 工具链跑通全链路验证；清 5 处既有 analyze warning（含 my_doctors_page 未用 import） |
| 2026-10 | R0.6 | 已完成 | miniapp wx 类型错误清零：miniprogram-api-typings + tsconfig types + requestSubscribeMessage 断言；全仓 typecheck 5 包全绿 |
| 2026-10 | R0.7 | 已完成 | README 英文化：英文为主 README.md + 中文 README.zh-CN.md 互链；两版对齐 |
| 2026-10 | prd-v1.1 | 已完成 | PRD×代码全量对照审计（证据存 var/prd-audit/ 三份报告）+ 输出中英 V1.1 修订版 PRD（docs/IBD病程管理程序PRD-v1.1.md、docs/IBD-Disease-Course-Management-PRD-v1.1.md）；原 V1.0 PRD 保留不动 |
| 2026-10 | T0 | 已完成 | Phase 0 基线扫描：模块/测试命令/T1–T7 缺陷定位/任务拆分/风险与 7 项裁决（只读，不改代码） |
| 2026-10 | T0.1 | 已完成 | ci.yml 依赖审计步骤缩进修复（YAML 解析恢复，js-yaml 验证 3 jobs 完整）· `259ec34` |
| 2026-10 | T0.2 | 已完成 | Phase 0/1 路线计划登记入 worklist（P8.1–P8.4：T0–T20、D1–D4、裁决记录、BLOCKED 清单） |
| 2026-10 | T1 | 已完成 | bloating 误写疲劳值修复：库 v9→v10 迁移（脏值置空 + data_flags bit0 标记，不静默覆盖）、腹胀独立 UI/保存/快捷模板、修复提示卡；新增 8 项回归测试，flutter test 106 全过、analyze 0 warning/0 error |
| 2026-10 | T0.3 | 已完成 | 用户点名最高优先级：软件工程强制约束落盘为 `docs/engineering-constraints.md`（项目级生效，原样入库不改写）；worklist 登记 |
| 2026-10 | T1.1 | 已完成 | 裁决「问题1 B」落地：修复标记仅在实际录入腹胀时清除（关态保存写 null）；v10 补偿脚本入库（幂等）；flutter test 107 全过、analyze 0 warning/0 error |
| 2026-10 | T1.2 | 已完成 | 裁决「问题5」疲劳小任务：开关关闭不再残留滑块旧值（关态写 null）；checkin_fatigue_ui_test 3 用例；flutter test 110 全过、analyze 0 warning/0 error |
| 2026-10 | T0.4 | 已完成 | 依赖安全治理：生产链 10 项 + dev 链 2 项 overrides（多主版本定向不误伤）；全量漏洞 106→73、生产 high/critical 清零；CI 门禁改 --prod（裁决 2a）；swiper override 12.2.0 落地、构建集成验证因既有 miniapp 构建损坏 BLOCKED（见 docs/dependency-audit-notes.md，建议 T0.5） |
| 2026-10 | T0.5 | 已完成 | miniapp 构建修复（babel.config.js + babel-preset-taro + 工作区 TS loader 规则）：build:weapp 编译成功（基线对照证实损坏为既有问题）；swiper 12.2.0 构建集成验证过（进产物）；裁决 3 的"限期验证"达成，运行时验证并入真机验收；登记 T21（工具链升级→门禁收紧） |
| 2026-10 | T2 | 已完成 | 来源标记如实化：parse_jobs.engine 持久化（迁移 1727600000000 可空列+down）+ confirm 按真实引擎写 skill\|ai + App 三档 + 契约可选字段；旧数据不回填（裁决④）；7 项 smoke 全过（新增 parse-source 9 断言）+ flutter 111 全过；证据 docs/audit-evidence/t2-lab-source.md |
| 2026-10 | T0.6 | 已完成 | 优先修复红 CI（E2E 红根因非 T2，系 R0.13/826d37f 遗留 DI 缺失致 API 起不来）：AuthModule 补 DevicePubKeyEntity 注册；启动探针 + 7 smoke 过；推送后 CI + Fullstack E2E 双绿 |
| 2026-10 | T3 | 已完成 | 本地 Skill 缓存闭环：txt 快速通道（skill_matcher 纯函数、全命中才本地、engine=skill 与 T2 闭环）、formatVersion 失效、clear/clearAll+设置页清理；不改服务端契约；新增 12 用例，flutter 123 全过、analyze 0 新增 info |
| 2026-10 | T4 | 已完成 | 注射提醒提前量可配置：ReminderPrefs 通用配置模块（T6 复用）+ 调度时刻纯函数 + 多提前量（含当天/1 天）+ 设置页多选与保存即重排；默认 {3} 兼容；新增 9 用例，flutter 132 全过；遗留：通知文案脱敏归 T6、ensureInjectionReminderRule 死代码归 T6 处置 |
| 2026-10 | T5 | 已完成 | 患者侧建议/审计/授权接真实 API（替换硬编码骨架，DoctorPatientSource 可注入 seam）；修 revoke 传 code→grantId 缺陷；诚实降级（本地未同步/收回失败不伪称）；测试暴露并修复不可变列表崩溃；新增 6 用例，flutter 137 全过、analyze 9（0 新增） |
| 2026-10 | T6 | 已完成 | 提醒体系补全：三类提醒（当天证件档/用药每日/复查自定义）+ ReminderScheduler 统一重排（修 cancelAll 互清隐患）+ 文案全脱敏（reminder_copy 禁词表测试）+ 删 ensureInjectionReminderRule 死代码（T4 移交）；新增 9 用例，flutter 146 全过、analyze 9（0 新增） |
| 2026-10 | T7 | 已完成 | 合规与安全前置（P0 收口）：非诊断/非治疗声明植入 5 解读页；DPIA+知情同意模板入 docs/compliance（⛔ 法务 BLOCKED，占位符化无真实个人信息）；生产安全 checklist 6 节 30 项；flutter 147 全过、analyze 9（0 新增） |
| 2026-10 | P0-验收 | 已完成 | T1–T7 独立验收复核（全量验证批重跑 + 验收点抽查 + git/worklist 一致性）：7/7 达标、无代码缺陷；F1 遗留 T6.4 状态更正、F2 PRD v1.2 刷新待点名 · 报告 docs/audit-evidence/p0-acceptance-2026-10-27.md |
| 2026-10 | P0-签发 | 已完成 | **用户确认签发 P0 验收**（T1–T7 关闭）；裁决：先做 F2「PRD v1.2 刷新」，随后进入 P1（T8 起） |
| 2026-10 | F2 | 已完成 | PRD v1.2 刷新：中英双版（docs/*PRD-v1.2.md）；14 组状态更正（来源标记/Skill 缓存/提醒体系/腹胀/数据模型/合规/患者端/遗留待办）；中英锚点交叉核验一致（7/7）；英文版原委托子任务失败无产物，由本体补完 |
| 2026-11 | V13-02/V13-03 | 已完成 | PRD v1.3（中文）：Skill v1.4.1 对齐修订——医学口径（FCP 分层/SES-CD 0–56/Limberg 0–3/SF-36 禁令/IBDQ 非 SIBDQ/PHQ-2·GAD-2）、新增 §1.5 边界与五态图例、§2.1.5–2.1.7 检查解析与指标字典、§2.2.3 注射医嘱优先纠偏、§2.2.4–2.2.5 监测/变更史、§2.4.1 统一时间轴、§2.8–2.11 四模块与规则表、§3.1/§3.2 数据模型、§4.5 自检、附录B 能力映射；保留 v1.2 原文 |
| 2026-11 | V13（PRD 修订） | 已完成 | PRD v1.3 + 对照分析 + 工作清单 + 两卷证据：`docs/IBD病程管理程序PRD-v1.3.md`（1569 行）、`docs/IBD-PRD-Skill对照分析-v1.4.1-vs-v1.2.md`、`docs/PRD-v1.3-工作清单.md`（43 项）、`var/prd-audit/v13-{issue-matrix,medical-evidence,code-evidence}.md`；P8.5 登记；用户裁决：仅中文 v1.3、英文列 V13-43 |
| 2026-11 | V13-44 | 待办 | 用户补充（2026-11-02）：医生对注射前后相差数天无强烈反对，实际日期与计划/预约不一致时**可**补充偏差理由（非强制）——PRD §2.2.3 规则 6、§3.1 字段；清单 V13-44（P1，依赖 V13-20） |

## P6 · 代码审查机制（T8）

> 目标：把"代码质量参差不齐"从个人经验问题，变成可执行、可验证、可度量的机制。
> 标准：[code-review-standard.md](code-review-standard.md) · 流程：[code-review-process.md](code-review-process.md) · 模板：[`.github/pull_request_template.md`](../.github/pull_request_template.md)

| ID | 任务 | 状态 | 验收标准 |
|----|------|------|----------|
| T8.1 | 代码审查标准与流程文档 + PR 模板 | 已完成 | 标准（S0–S3 严重度 / C1–C4 分级 / 8 组维度清单 / R1–R13 红线 / G0–G3 门禁）+ 流程（角色 / 7 步 / 时间盒 / AI 代理 7 条规则 / 4 周路线图）+ PR 模板；均与本仓库实际缺陷对应 |
| T8.2 | ESLint 9 + Prettier 3 + EditorConfig 基线 | 已完成 | `eslint.config.mjs`（扁平配置，类型感知规则限有 tsconfig 的目录）；`pnpm lint` = 0 error / 9 warning（151 文件）；存量 17 处违规基线化到 `eslint-suppressions.json`；`.prettierrc.json` 对齐既有风格（双引号/分号/2 空格/尾逗号） |
| T8.3 | CI 门禁落地（lint / 全量 typecheck / PR 级 E2E / 密钥扫描） | 已完成 | `ci.yml` 新增 lint 与 typecheck job；`ci-fullstack.yml` 增加 pull_request 触发；`scripts/scan-secrets.mjs`（全仓 65658 行 0 误报，正向检出已验证）；`scripts/check-format-changed.mjs`（增量格式门禁） |
| T8.4 | 两条硬规则可执行化 | 已完成 | 硬规则 1：`.github/workflows/pr-guard.yml` + `scripts/pr-guard.mjs`（任务号 / 描述章节 / 定级 / 勾选数 / 证据区），正负用例已本地验证；硬规则 2：分支保护配置见 [branch-protection.md](branch-protection.md)（**需仓库管理员手动开启**） |
| T8.5 | 解除 17 处 lint 基线（修存量违规） | 待办 | 逐条修 `eslint-suppressions.json` 中的 17 项（12 unused-vars、5 promise 相关）；修完执行 `pnpm lint:prune` 收缩基线；promise 类需补失败路径处理，不可只加 `void` |
| T8.6 | 补齐 `api-client` / `ui-tokens` 的 tsconfig 与 typecheck | 待办 | 两包当前无 tsconfig、`api-client` 无 typecheck 脚本，导致 `pnpm -r typecheck` 静默跳过；补齐后类型感知 lint 可扩展到 packages |
| T8.7 | Dart 侧增量格式门禁（`dart format`） | 待办 | 当前 `flutter analyze` 只查正确性不查格式；按 T8.2 同样的增量策略接入，避免一次性重排 75 个文件 |

## 二次验证 / 审阅遗留（跨会话必读）

> 下列为排查中**记入但未关闭**的事项，切换会话后从这里继续，勿丢。

| ID | 事项 | 状态 | 验收 |
|----|------|------|------|
| R0 | 代码审查修复轮（C1 CI 测试 / C2 IDOR / H1 检验数据源收敛） | 已完成 | 三处按序落地 + 二次验证 |
| R0.1 | CI：`flutter test` 跑全部测试文件（原只跑 1 个） | 已完成 | ci.yml 全量 `flutter test` + analyze `--no-fatal-infos`（warning/error 阻塞） |
| R0.2 | API 全模块 IDOR 归属校验审计 + 修复 | 已完成 | 审计确认大部分到位；修 `GET /patients/:id` 越权（改 `getOwnedBasic`）+ 医生审核 `DOCTOR_ADMIN_TOKEN` 默认值收紧（timing-safe + env-guard 拦截） |
| R0.3 | 检验套餐数据单一数据源（app.js/domain-types/lab_panels.dart 三处重复） | 已完成 | Dart 加 `kCoreLabNames`、`latestCore()` 复用；app.js exportDart 输出权威 `kCoreLabNames` + 转义修复；新增跨副本一致性守卫 `test_lab_data_consistency.py` 挂 CI（正/负向均已验证） |
| R0.4 | 本地全链路验证（装 git/node/pnpm/python3.12 工具链） | 已完成 | build:api + typecheck（@ibd/api 等 4 包零 error）· flutter test 98 全过 · flutter analyze 0 warning/0 error · parse-worker 一致性守卫 + test_ai_engine ALL_PASS |
| R0.5 | 清理既有 analyze warning（避免 CI 卡既有问题） | 已完成 | 删 `ibd_api_client.dart` 4 处冗余 cast + `my_doctors_page.dart` 未用 import；analyze warning 16→0；my_doctors_page 未用 import 已补 |
| R0.6 | 修复 miniapp 既有 wx 类型错误（审查 M1） | 已完成 | 装 miniprogram-api-typings + tsconfig types 引入 + requestSubscribeMessage 参数按微信语义断言（规避 Taro 类型 entityIds 支付宝必填缺陷）；miniapp typecheck 15 error→0；全仓 5 包 typecheck 全绿 |
| R0.7 | README 英文化（英文为主 + 中文切换链接） | 已完成 | `README.md` 改为英文主版（含 `简体中文` 切换链接）；原中文版移至 `README.zh-CN.md`（含 `English` 切换链接）；session-worklist 锚点改指 zh 版；两版对齐（补 SF-36、CI 表述更准确）；审阅并修正 docs 夸大实现 |
| R0.8 | 安全审查修复轮2（H3 依赖治本 + C1 文件穿越 + C2 文档诚实） | 进行中 | H3 xlsx→exceljs（消无补丁 critical）；C1 resolveSafe 加固 + meta IDOR 形状校验（8 穿越向量全拦）；C2 PRD 虚假 AES-256/PIPL 声明如实修正；后续 H1-H8/M 待办 |
| R0.9 | 安全加固（H1 CORS/Swagger + H5 端口/Redis + H6 compose 默认 + H7 parse 穿越/大小 + H8 SSRF） | 已完成 | H1 CORS 白名单+Swagger 生产禁用；H5 端口绑 127.0.0.1+Redis requirepass；H6 NODE_ENV 强制/DEV_SMS 无默认；H7 load_skill 白名单+uploads 大小/PDF 魔数；H8 拒 URL/绝对路径 objectKey；py_compile+回归全过；余 H2 限流/H3 会话绑定/H4 审核角色/M 待办 |
| R0.10 | H2 余下：限流覆盖登录/上传 + XFF 伪造防护 | 已完成 | TRUSTED_PROXY 控制 XFF（默认不信任）；loginLimiter 覆盖 auth/doctor 登录注册；uploadLimiter 覆盖 presign/upload；typecheck+build+smoke 全过 |
| R0.11 | M 系列加固（M1 gitignore 密钥 + M3 grant code 脱敏 + M5 ReDoS 防护） | 已完成 | M1 .gitignore 补 Firebase/jks/pem（修 firebase-setup 虚假声明）；M3 listForPatient 确认后 code 脱敏；M5 skill_engine safe_re_search 拒灾难性回溯正则；typecheck+py_compile+回归全过；余 H3 会话绑定/H4 审核角色/M4,M6,M7 待办 |
| R0.12 | M 系列收尾（M2 venv 确认 + M4 fetch 大小上限 + M6 grant 限流/wrappedDek 校验 + M7 客户端 PII 文档） | 已完成 | M2 git 确认 venv 0 追踪；M4 fetch_object_bytes 三处 read 加 20MB 上限；M6 grantLimiter 限流 + wrappedDek base64 校验；M7 web README 客户端 PII 暴露提示；typecheck+build+py_compile+回归全过；余 H3 会话绑定/H4 审核角色 待办 |
| R0.13 | H3 DPoP-lite 设备绑定 + H4 医生审核轻量加固 | 进行中 | H3: device_pubkeys 表 + Ed25519 持有证明 + JWT 绑定公钥 + X-PoP 校验 + REQUIRE_POP 渐进开关（默认关）；H4: approve 审计日志 + 限流 + HTTPS 告警 |
| T4.2b | PC Web 批量解析接真上传（presign/enqueue/confirm） | 已完成 | 真 API：presign→PUT→enqueue→轮询→confirm(deleteSource) |
| T2.6 | `GET /parse/jobs/:id` 补归属校验（getForUser） | 已完成 | 他人 jobId 返回 404 · tsc 通过 |
| T2.7 | Web 装依赖后跑 `tsc --noEmit` | 已完成 | 零 error · 顺带修复 api-client 重复方法（prd-v15-gaps） |
| T2.8 | 真机/模拟器 UI 回归（analyze 通过后） | 已完成 | Widget 回归全过（五 Tab/设置大字/语言/诊断）· 真机残留见 T2.4/T2.5 |
| T2.9 | 清理 info：`const FirebaseOptions` · Radio 弃用改 RadioGroup | 已完成 | analyze **No issues found** |
| T4.2a | T4.2 清单措辞：与真上传行为一致 | 已完成 | 已改为「真上传链路」描述 |
| SWIPER-R1 | swiper 12 override 运行时真机兼容（限期验证风险项） | 进行中（2026-11-13 补静态证据，真机项仍缺） | 裁决（2026-10-26）：接受风险、不直接豁免；**owner：lead（协调）+ 真机执行人待指派；截止 2026-11-09 已逾期，按用户 2026-11-13 裁决继续限期、不回滚 override**；矩阵/场景/回滚预案见 [audit-evidence/t05-build-and-swiper.md](audit-evidence/t05-build-and-swiper.md)。**2026-11-13 静态取证结论**：① `pnpm why swiper -r` 确认 override 生效（`@tarojs/components 3.6.34` → swiper 12.2.0，其 package.json 原声明 6.8.0）；② `apps/miniapp/src` **零** `Swiper`/`swiper` 引用，小程序代码不用该组件；③ `apps/miniapp/dist/*.js` 中 `swiper` 仅 7 处、**全在 `taro.js`**，且全为组件属性表/组件映射/标签名表/hydrate 判断，`SwiperCore`/`swiper-wrapper`/`slidesPerView`/`wrapperEl`/`watchSlidesProgress`/`swiper-button-next` 等 swiper 12 运行时符号 **0 命中**；`hammer`/`hls.js`/`stencil` 亦 0 命中 → weapp 打包不加载 swiper 运行时，**运行时污染风险在产物层面不成立**。**未闭环部分**：本机未安装微信开发者工具（三处常见安装路径均不存在），矩阵里「微信基础库 ≥2.30 真机渲染 / 冷启动 + 弱网」仍无证据，需在装有开发者工具或真机的环境补做后才能把本项置为已完成 |

## P9 · 评审 P0 修复（2026-11-12）

> 来源：`docs/task-inventory-2026-11-12.md` Wave 0。8 组任务一次性落地；C1/C3 无 TS 单测基建，验证以 typecheck + 代码复核为主（不伪造 E2E）。

| ID | 任务 | 状态 | 验收 / 证据 |
|----|------|------|-------------|
| W0-01 | C1 `medications/timeline` 跨租户泄漏 | 已完成 | 先 `resolveOwnedPatientId`，副作用查询加 `m.patientId = :pid`；新增 `e2e-authz.mjs`（A 写入 → B 不可见 + 直读 404）并接入 `ci-fullstack.sh`；**本地无 DB/Redis 未执行，CI fullstack 覆盖** |
| W0-02 | C2 SQLCipher 迁移残留明文 `.plain.bak` | 已完成 | 移除明文备份副本 + 启动/迁移双清理；`local_db_plain_backup_test` 幂等用例通过 |
| W0-03 | C3 Web 批量解析 confirm 失败仍删原件 | 已完成 | 映射抽到 `apps/web/src/lib/parse-items.ts`；失败不删原件、不标 done；`parse-items-smoke.mjs` 9 项断言通过并接入 CI typecheck job |
| W0-04 | C4 定性值 NaN 打挂解析 | 已完成 | worker `value=None + value_text`；运算符值不参与数值比较；App 映射拒绝 NaN；`test_ai_engine` 新增用例 ALL_PASS |
| W0-05 | 备份/恢复同构 + 去重 + 换机可解密 | 已完成 | 导出/恢复覆盖 12 类（含检查/手术/打卡/副作用）；按主键/日期/唯一键幂等；云快照新增 `kdfSalt`（迁移 1727700000000）；恢复支持原设备标识；`lab_and_backup_test` 二次导入 0 新增 |
| W0-06 | 白蛋白精确匹配 | 已完成 | `seriesByName` 由 `LIKE '%name%'` 改 `name_norm = ?`；测试证明前白蛋白不混入 |
| W0-07 | 注射首屏加载 + 覆盖确认 | 已完成 | `initState` 加载排期并按最近一针回填起始日；重新生成前弹覆盖确认 |
| W0-08 | UI P0 八组 | 已完成 | 匿名会话真 token（App 三处 + 小程序检验页）；打卡未触碰写 null 且停止自动写细表；检验记录列表/编辑/删除/合并重复；小程序 DEMO 改空态、摘要删 uuid；量表未答禁存 + PHQ-9 Q9 求助卡；密文备份改名 + 明文导出风险提示 |

**验证记录（2026-11-12）**
- `flutter analyze` → 0 error / 0 warning（9 info 为既有基线）
- `flutter test` → **153 全过**（新增 6 用例：C2 清理、C4 映射、H17 精确匹配、备份幂等、打卡新语义）
- `pnpm -r --if-present typecheck` → 7 包全过
- `pnpm lint` → 0 error / 8 warning（存量基线，已 `lint:prune`）
- parse-worker `test_ai_engine` → ALL_PASS；`test_lab_data_consistency` → OK

**遗留 / 未验证**
- C1 的 E2E 需 DB/Redis（本机无 Docker，标 BLOCKED）；CI fullstack 已接入。C3 已有纯函数回归 + CI 门禁。
- 云快照换机恢复需真机 + 后端联调（本机仅验证加解密单元逻辑与迁移编译）。
- 检验记录页的「合并重复」为手动触发，未做自动入库去重（避免静默合并不同报告）。

## P10 · UI 设计评审遗留（2026-11-10 走查 → 2026-11-12 落地）

> 报告：[design/ui-review-2026-11-10.html](design/ui-review-2026-11-10.html)。走查阶段 U1–U9 为设计目标；2026-11-12 已完成 U1–U6、U8–U14、U16、U17 的落地，2026-11-13 补齐 U7、U15 —— **U1–U17 全部已完成**（验证见各行）。

| ID | 事项 | 状态 | 验收 |
|----|------|------|------|
| U0 | UI 设计评审与优化方案（文档） | 已完成 | 9 项诊断（含代码位置与 WCAG 实测对比度）+ 令牌/组件规范 + 3 组改版线框 + 路线图 |
| U1 | P0 首页错误态：`dashboard_tab.dart` `catch (_) {}` → 错误提示 + 重试 | 已完成 | 新增 `_loadError` + `_LoadErrorBanner`（dangerSoft 底 + 重试按钮 44 高）；读取失败不再渲染为 0 值；`dart analyze lib` 0 error/0 warning |
| U2 | P0 暗色模式二选一：先「关掉」，U5 后再恢复 | 已完成 | 先 `themeMode: light` 止血；**U5 完成后已改回 `ThemeMode.system`**，真机明暗双模式验收通过 |
| U3 | P0 对比度修复（6 处低于 AA） | 已完成 | `theme.dart`：textSecondary→#475569(7.03)、success→#047857(5.48)、warning→#B45309(5.02)、danger→#B91C1C(6.47)、FilledButton 底→primaryDark(5.47)；首页渐变改 #0F766E→#115E59 + 白字（≥5.47）；次按钮由「提亮」改「压暗」(7.1) |
| U4 | P0 打卡页底部吸附保存 + 草稿持久化 | 已完成 | `symptom_page.dart`：`_CheckinSaveBar` 常驻底部（含草稿状态文案）；草稿节流落盘 `ibd_checkin_draft_v1`（≤1 次/800ms + 退后台补写）；跨日草稿丢弃；保存成功清除；存储不可用静默降级；草稿**异步套用**不阻塞首屏。新增 `test/checkin_draft_test.dart`（2 例）。验证：`flutter test` **149 全过**、`flutter analyze --no-pub` 0 error/0 warning |
| U5 | P1 设计令牌落地（`IbdTokens` + `context.ibd`，取代 `packages/ui-tokens` 占位） | 已完成 | 新增 `IbdPalette extends ThemeExtension`（bg/surface/surfaceAlt/textPrimary/textSecondary/outline/divider/brandInk/brandSoft/success/warning/danger/dangerSoft，明暗两套）+ `extension IbdThemeX on BuildContext { ibd }`；20 个页面文件 243 处硬编码色迁移到 `context.ibd.*`；`_LineChartPainter`/`_DomainSparkPainter` 改为注入颜色（painter 无 BuildContext）；暗色主题补齐 inputDecoration/filledButton/navigationBar 三项。验证：`dart analyze lib` 0 error/0 warning；`flutter test` **149 全过**；真机明暗双模式截图（`.workbuddy-ai/screens/21~24`）无不可读文字 |
| U6 | P1 组件收敛（IbdCard / IbdSectionHeader / IbdChoiceChip / IbdScoreChip / IbdStickyAction / IbdMetric / IbdEmptyView / IbdEmptyInline） | **已完成** | **第一刀**：`IbdCard` + `IbdSectionHeader` 收敛 4 套卡片（`_SectionCard`/`_NavCard`/`_ModuleCard`/`_StatChip`），删 `IbdSectionTitle`。 **第二刀**：`IbdChoiceChip`（替代逐字相同的 `_BloodChip`/`_FeelingChip`）、`IbdScoreChip`、`IbdStickyAction`（打卡吸附栏）、主题 `chipTheme`（统一 9 处 Material chip）、`IbdEmptyInline`（6 处空态，含 CTA）、设置页 6 处标题统一。 **第三刀**：`IbdMetric`（`stat` 数值块 / `status` 状态灯两种命名构造）替代首页三灯 + 首页统计块 + 活动度详情页三灯三份实现；新增 `IbdMetricTone` 与 `IbdMetricTone.ofLight()`；领域层补 `inflammationStateText()`；删 `_lightColor`×2、`_lightTextColor`、`_lightState`、`_StatChip`。 **顺带修掉的暗色缺陷**：Bristol 量表选项写死 `Colors.white` 底、症状日历严重度格白字压亮底、服药打卡日期格 `primary` 底（3.74:1）——统一走新增的 `onBrand` 令牌。 **活动度详情页原来只有圆点颜色、没有状态文字**（WCAG 1.4.1 违规），第三刀补上「偏高/正常/未测」。 验证：`flutter test` **158 全过**（新增 `test/ibd_metric_test.dart` 7 例，钉住「状态灯必须有文字 + 语义合并」）、`dart analyze` **2 info / 0 error / 0 warning**；真机明暗双模式目视首页/详情/设置/空态（`.workbuddy-ai/screens/u6_*.png`、`u6b_*.png`） |
| U7 | P2 分析 Tab 四组分层 + 三组合并 | **已完成**（2026-11-13） | 14 张平铺 `_NavCard` → 4 组（趋势与时间线 2 项 / 记录与明细 3 项 / 就诊与报告 5 项 / 分析与参考 4 项），每组一张 `IbdCard` 内嵌 `_NavRow`（`InkWell` + 36dp 图标块 + 标题 + 2 行副标题 + chevron），组间 `IbdSectionHeader` 分隔。合并：**发作预警→分析与参考**（与 AI/规则分析同为"系统替你看"）、**年度报告→就诊与报告**（与就诊摘要同为"拿去给别人看"）、**食物与排便→记录与明细**（与排便细表同一套数据）。`_NavCard` 类删除，改为 `_NavRow` + `_RowDivider`（左侧 62 对齐图标列）。验证：`flutter test` **177 全过**（含新增 `test/analysis_tab_groups_test.dart` 4 例：分组标题唯一 / 14 入口无漏迁 / 分组顺序 / 行内 InkWell 可点）、`flutter analyze --no-pub` 2 info / 0 error / 0 warning |
| U8 | P2 无障碍专项（Semantics 覆盖 / 非颜色编码 / 字号自适应 / 触控区） | **已完成** | **语义覆盖**：3 个滑块加 `Semantics(container:false, label:…)` + `semanticFormatterCallback`（读屏念「腹痛程度 5 分」而非「50%」）；Bristol 选项与日历格加 `button`/`selected`/完整标签；夜醒加减 `IconButton` 补 tooltip（原本只念「按钮」）；`IbdCard(onTap)` 加 `MergeSemantics`（整卡读成一句）。 **修掉一个自己引入的缺陷**：`Semantics(button:true, excludeSemantics:true)` 会连 InkWell 的 tap 动作一起丢掉——读屏念「按钮」但双击无效，比不加语义更糟。给 `IbdChoiceChip`/`IbdScoreChip`/日历格/Bristol 补回 `onTap`，并写了一条遍历语义树的守卫测试防复发。 **非颜色编码**：日历格有记录时印出严重度数值（「11」下方「5」），图例改为「1–3 轻 / 4–6 中 / 7–10 重」——灰度截图下「5 → 4–6 中」可纯文字推出（实测转灰度验证）。 **触控区**：日历格 34→40（含外边距 44），满足 ≥44。 **简洁模式真正生效**：原来只藏一条横幅；现在收掉「快捷入口 + 本机数据」，只留今日待办 + 活动度，并补一行「简洁模式已开启…可在我的→可用性关闭」避免误认为页面坏了。 验证：`flutter test` **167 全过**（新增 `test/a11y_test.dart` 9 例：滑块/选项/开关/保存按钮标签、按钮可激活守卫、日历语义与触控区、分档文案边界）；`dart analyze` 2 info / 0 error / 0 warning；真机：1.25× 打卡页三屏无溢出条纹、简洁模式开关前后、日历灰度可辨（`.workbuddy-ai/screens/u8_*.png`） |
| U9 | P1 PC Web 工具栏分组 + 删除可撤销 + 去 `AI生成` 水印 + 脏状态 | **已完成** | **去水印**：删除 `<!-- AI生成 -->` 注释与 `<p data-aigc-mark>` 渲染节点（该节点原本直接显示在页面顶部）。 **工具栏分组**：8 个按钮平铺 → 3 组（套餐：新建/复制/删除；数据：导入/导出 JSON/导出 Dart/重置；保存：状态 chip + 主按钮），删除与重置不再和常规操作并排。 **删除可撤销**：`confirm()` 全部移除（4 处），改为执行后 6 秒「撤销」提示条；`pushUndo()` 存整份 panels 快照（上限 10），删除小项 / 删除套餐 / 重置默认 / 导入 JSON 共用同一条撤销路径；另支持 Ctrl+S 保存、Ctrl+Z 撤销。 **脏状态**：工具栏新增「已保存 / ● 未保存」chip（琥珀色）+ 标签页标题前缀 `•`；`dirty` 由 11 处散落赋值收敛为 `markDirty()/markClean()`；`beforeunload` 保持拦截。 顺带：内联 SVG favicon（消除每次加载的 404）、`:focus-visible` 焦点环、toast 加 `role=status aria-live=polite`、导入按钮从行内 `onclick` 改为统一绑定。 验证：Playwright（真实 Chromium）**18/18 通过** + 3 项补充（保存重载保留、撤销后保存落盘、控制台无报错）；截图 `.workbuddy-ai/screens/web/w*.png`。过程中脚本抓到一个自己引入的缺陷：全局替换 `dirty = true;` 把 `markDirty()` 函数体也换成了自调用，导致递归爆栈、脏状态永不生效——已修。 |
| U10 | **构建阻塞修复**：`android/build.gradle.kts` 的 `buildscript` 块缺 `repositories`，`google-services:4.4.2` 无法解析（`no repositories are defined`），APK 构建失败 | 已完成 | 在 `buildscript` 内补 aliyun + google + mavenCentral 仓库；`flutter run -d emulator-5554` 成功安装并启动；真机走查见下 |
| U11 | 首页四宫格定高（去 `childAspectRatio: 1.15`，改 IntrinsicHeight + 内容定高）+ 活动度灯加状态文字 | 已完成 | 真机验证（`.workbuddy-ai/screens/17_final_normal.png`、`15_final_largefont.png`）：卡片高度 ~156→~110dp，两行完整可见、「本机数据」进入首屏；CRP/ESR/钙卫 下增「偏高/正常/未测」文字（dot 颜色 + 文字双编码 + Semantics label）；1.25× 大字无溢出条纹；无药物时不渲染摘要（原被截成「暂无在用…」） |
| U13 | 真机视觉回归（明暗双模式）：5 Tab + 14 个二级页 | 已完成 | 覆盖 5 Tab × 明/暗 + 11 个二级页（明）+ 4 个二级页（暗）。修复 2 处：① 数据导出页顶部「空白胶囊 + 锁图标」（ListTile 缺 title/subtitle）→ 补「导出前须知 / CSV 为明文…」；② 量表未作答即显示「当前合计 0 分 · 无或极轻微」→ 改为「尚未作答」（`_answered` 集合区分"选了 0 分"与"没答"）。截图存 `.workbuddy-ai/screens/reg/` |
| U14 | **P1 空白页**：药物评价 / 同城病友·就诊指南 / 2025 年度报告 整页无内容 | **已完成** | **根因**：主题里 `filledButtonTheme`/`outlinedButtonTheme` 的 `minimumSize: Size.fromHeight(48)` 实为 `Size(∞, 48)`（无限最小宽度）。三页都把按钮放在 `Row` 里（drug「查询」、geo「发帖」、annual「重新生成」），Row 横向无界 → 按钮要求无限宽 → 布局失败 → **整个 ListView 静默不绘制**（不报错、不留红框）。**修复**：给这三处按钮显式 `styleFrom(minimumSize: Size(64, 44))`。另新增 `core/ui/state_views.dart`（加载/错误/空态）并接入三页 + `Future.timeout(8s)` 兜底。**验证**：真机三页内容像素占比 0.0 → 40.3% / 46.5% / 75.5%；`flutter test` 149 全过；`dart analyze` 0 error。定位方法：用 `--dart-define=BISECT=N` 对 children 做二分（20 正常 / 21 白屏）锁定到具体子组件 |
| U16 | **P1 本地库密钥不匹配无恢复路径**：重装/覆盖安装后 SQLCipher 报 `file is not a database`，App 停在满屏空白 | **已完成** | `main.dart` 启动时 `LocalDb.instance.database.timeout(10s)` 探测；失败则进 `features/recovery/db_failure_page.dart`（说明成因 + 重试 + 清空重建 + 可复制的排查线索）。新增 `DbKeyService.clearKey()` 与 `LocalDb.resetLocalDb()`（关连接 → 删 db/-wal/-shm → 丢密钥）；重建需二次确认，文案明确「无法撤销、可事后从 JSON 备份/密文同步恢复」。验证：新增 `test/db_failure_page_test.dart` 2 例（内容完整、取消不执行）→ **151 全过**；真机明暗两套截图（`.workbuddy-ai/screens/reg/sheet_R.png`）文字可读、按钮无溢出 |
| U17 | **P1 主题隐患根治**：`minimumSize: Size.fromHeight(48)`（无限宽）导致按钮进 Row 就整页静默空白 | **已完成** | ① 主题 3 处改 `Size(64, 48)`（`grep -c Size.fromHeight` = 0，仅注释保留历史说明）；② 按「按钮分层」迁移 12 处 Block CTA 为 `SizedBox(width: double.infinity, child: ...)`：打卡保存 / 注射生成排期 / 检验保存 / 导出 CSV / 量表保存 / 用药保存 / 药物评价保存 / 同城保存档案 / 排便记一笔 / 食物记一笔 / 我的医生确认授权 / 登录关联手机号；其余内联按钮（查询、发帖、重新生成、分享、弹窗动作）回归内容宽。验证：`flutter test` **151 全过**、`dart analyze` 0 error；真机目视 5 Tab + 药物评价/年报/导出（`.workbuddy-ai/screens/reg/sheet_U*.png`）——Block CTA 仍整行宽、内联按钮层级清晰、无溢出 |
| U15 | P2 细节：检查与手术空态无 CTA；设置页若干 subtitle 被截断 | **已完成**（2026-11-13） | ✅ 检查与手术「检查/手术」空态已升级为 `IbdEmptyInline`（图标 + 说明 + 「添加检查/添加手术」CTA）；排便细表历史、我的医生三处空态同步升级。 ✅ 设置页 10 处 `ListTile`/`SwitchListTile` 的 `subtitle` 全部补 `maxLines: 2` + `overflow: TextOverflow.ellipsis`（AI 解析 / 注射提醒 / 用药提醒 / 匿名诊断上报 / 大字体 / 简洁模式 / 系统推送 / 本地库 / 密文备份 / 关联手机号），长文案改为 2 行不再被腰斩。验证：`flutter test` **177 全过**、`flutter analyze --no-pub` 2 info / 0 error / 0 warning |
| U12 | 无障碍缺陷：`main.dart` 覆盖系统字体缩放（WCAG 1.4.4） | 已完成 | 改为 `TextScaler.linear(system.scale(1.0) * appScale)` 相乘；系统 1.5× × 应用 1.25× 同时生效；`flutter test` 149 全过 |

> **本机跑 Flutter 测试/分析的可用命令（2026-11-10 实测，开发者模式已开启）**：
>
> | 命令 | 是否可用 | 说明 |
> |------|----------|------|
> | `flutter analyze` | ✅ 可直接跑 | 开发者模式开启后 symlink 报错消失；当前 9 info / 0 error / 0 warning |
> | `flutter test` | ⚠️ 需清代理 | 本机 `http_proxy=127.0.0.1:64466` 会拦截 `flutter_tester` 的本地 WebSocket（`Invalid WebSocket upgrade request`） |
> | `flutter devices` / `flutter run` | ✅ 已恢复 | 放行 `reg.exe` 后设备枚举正常（Windows / Chrome / Edge / 模拟器） |
>
> **在模拟器上跑 App 的完整命令（2026-11-10 实测）**：Gradle 需要联网下载依赖，而 `flutter run` 的 VM service 走 localhost，二者对代理的需求相反，故**只给 Gradle 传代理、Dart 侧不设代理**：
>
> ```bash
> # 1) 启动模拟器（AVD: ibd_api34）
> /c/dev/android-sdk/emulator/emulator.exe -avd ibd_api34 -no-boot-anim -no-audio
> # 2) 构建并运行：清空代理变量，仅用 GRADLE_OPTS 给 Gradle 代理
> env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
>   GRADLE_OPTS="-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=64466 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=64466" \
>   flutter run -d emulator-5554 --no-pub --dart-define=IBD_API_BASE=http://10.0.2.2:3000
> # 3) 截图
> adb exec-out screencap -p > shot.png
> ```
>
> 坑：`GRADLE_OPTS` 里的 `|`（如 `nonProxyHosts=localhost|127.0.0.1`）会被 cmd 当成管道，报“不是内部或外部命令”，不要带该参数。
>
> ```bash
> # 测试（唯一需要清代理的一步）
> env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY flutter test
> ```
>
> 注：`flutter pub get` 会以 LF 重写 `windows/linux/macos` 下 7 个 generated 文件。已用根目录 `.gitattributes` 把这 7 个文件固定为 `text eol=lf`，`pub get` 后不再产生「仅换行差异」的脏文件（2026-11-10 实测：pub get + 全量测试后 `git status` 无 generated 改动）。

**规范提醒**：任何新增工作（含审阅遗留、bugfix、文档）必须**同时**写入本清单（ID/任务/状态/验收），避免会话切换丢失。
