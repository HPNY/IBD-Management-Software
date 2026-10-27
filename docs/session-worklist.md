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
| T6.4 | V2 扩展：饮食 / 药物评价 / 同城病友 / AI 分析 | 待办 | 已拆解为四轨子包 D1–D4 · 见 [t64-v2-expansion](compose/spec/t64-v2-expansion.md) |
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
| T0.5 | 修复 miniapp 构建 + swiper 限期集成验证 | 已完成 | 裁决「点名 T0.5；swiper 先保留限期验证」：补 babel.config.js + babel-preset-taro + 工作区 TS loader；build:weapp 编译成功，swiper 12.2.0 进产物验证通过；运行时验证随真机验收 · `task/t0.5-miniapp-build-fix` |
| T2 | 修复检验来源标记失真 | 已完成 | confirm 按任务真实引擎写 source（skill\|ai）；App 三档标记；旧数据不回填（裁决④）；smoke:parse-source 9 断言 + 迁移行为级探针 + flutter 111 全过 · 证据 docs/audit-evidence/t2-lab-source.md · `task/t2-lab-source-accuracy` |
| T0.6 | 优先修复红 CI：AuthModule DI 接线（R0.13 遗留） | 已完成 | 裁决「CI 红优先修复」：TypeOrmModule.forFeature 补 DevicePubKeyEntity；启动探针证实 DI 恢复；推送后 CI + Fullstack E2E **双绿** · `task/t0.6-auth-di-fix` |
| T3 | App 本地 Skill 缓存可读/可命中/可清理 | 待办 | 命中路径测试或可复现验证；清理/失效逻辑；不改服务端解析契约 |
| T4 | 注射提醒提前天数可配置 | 待办 | 默认 3 天兼容；配置持久化；调度读配置；含提前 1 天/当天结构；设置页入口 |
| T5 | 医生端患者侧建议/审计接真实 API | 待办 | 真实数据可见；scope 不泄露未授权数据；空态/错误降级；测试或可复现验证 |
| T6 | 提醒体系补全（用药/复查/当天证件） | 待办 | 三类可创建/取消；复用 T4 配置结构；通知无敏感病历；调度计算测试 |
| T7 | 合规与安全前置 | 待办 | 非诊断/非治疗声明可见；DPIA/知情同意模板入 docs（法务 BLOCKED）；生产安全 checklist |

### P8.2 · P1 夯实（G0 前，按用户指定顺序领取，未点名不开工）

| ID | 任务 | 状态 |
|----|------|------|
| T8 | App 趋势增强：多指标叠加/3M/6M/1Y/全部/用药节点/钙卫蛋白 200 阈值线 | 待办 |
| T9 | 时间线增强：疾病/不良反应事件、点击详情、年/月缩放、PDF 导出 | 待办 |
| T10 | 导出补全：就诊摘要/时间线/年报 PDF（DOCX 仅评估不实现） | 待办 |
| T11 | 注射排期夯实：诱导/维持双频率、延迟顺延、实际日期 | 待办 |
| T12 | 副作用记录 App UI（接现有 API） | 待办 |
| T13 | 检查/手术服务端化（实体/API+迁移方案；附件仅评估） | 待办 |
| T14 | Flare 夯实：体温字段/发热条件、评估持久化、摘要复制 | 待办 |
| T15 | i18n 中英文界面生效 + 简洁模式真正精简 | 待办 |
| T16 | 跨端同步升级：记录级去重合并、Web↔App 互通、防重复恢复 | 待办 |
| T17 | 相机拍照上传（保留文件选择） | 待办 |
| T18 | 年度报告增强：年度指标趋势图、Web 年报只读/导出 | 待办 |
| T19 | 解析 Skill 夯实：check_fn 统一异常判定、multiline 执行、accuracy 统计口径 | 待办 |
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

---

## 建议开工顺序

1. **T2.1 → T2.2**（推送真发闭环）∥ **T5.1**（隐私承诺，改动面小）
2. **T3.1**（小程序从 0 到 1）
3. 其余按 P3 → P4 收尾 → P5/P6/P7

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
| R0.6 | 修复 miniapp 既有 wx 类型错误（审查 M1） | 已完成 | 装 miniprogram-api-typings + tsconfig types 引入 + 
| R0.7 | README 英文化（英文为主 + 中文切换链接） | 已完成 | `README.md` 改为英文主版（含 `简体中文` 切换链接）；原中文版移至 `README.zh-CN.md`（含 `English` 切换链接）；session-worklist 锚点改指 zh 版；两版对齐（补 SF-36、CI 表述更准确）；审阅并修正 docs 夸大实现 |
| R0.8 | 安全审查修复轮2（H3 依赖治本 + C1 文件穿越 + C2 文档诚实） | 进行中 | H3 xlsx→exceljs（消无补丁 critical）；C1 resolveSafe 加固 + meta IDOR 形状校验（8 穿越向量全拦）；C2 PRD 虚假 AES-256/PIPL 声明如实修正；后续 H1-H8/M 待办 |
| R0.9 | 安全加固（H1 CORS/Swagger + H5 端口/Redis + H6 compose 默认 + H7 parse 穿越/大小 + H8 SSRF） | 已完成 | H1 CORS 白名单+Swagger 生产禁用；H5 端口绑 127.0.0.1+Redis requirepass；H6 NODE_ENV 强制/DEV_SMS 无默认；H7 load_skill 白名单+uploads 大小/PDF 魔数；H8 拒 URL/绝对路径 objectKey；py_compile+回归全过；余 H2 限流/H3 会话绑定/H4 审核角色/M 待办 |
| R0.10 | H2 余下：限流覆盖登录/上传 + XFF 伪造防护 | 已完成 | TRUSTED_PROXY 控制 XFF（默认不信任）；loginLimiter 覆盖 auth/doctor 登录注册；uploadLimiter 覆盖 presign/upload；typecheck+build+smoke 全过 |
| R0.11 | M 系列加固（M1 gitignore 密钥 + M3 grant code 脱敏 + M5 ReDoS 防护） | 已完成 | M1 .gitignore 补 Firebase/jks/pem（修 firebase-setup 虚假声明）；M3 listForPatient 确认后 code 脱敏；M5 skill_engine safe_re_search 拒灾难性回溯正则；typecheck+py_compile+回归全过；余 H3 会话绑定/H4 审核角色/M4,M6,M7 待办 |
| R0.12 | M 系列收尾（M2 venv 确认 + M4 fetch 大小上限 + M6 grant 限流/wrappedDek 校验 + M7 客户端 PII 文档） | 已完成 | M2 git 确认 venv 0 追踪；M4 fetch_object_bytes 三处 read 加 20MB 上限；M6 grantLimiter 限流 + wrappedDek base64 校验；M7 web README 客户端 PII 暴露提示；typecheck+build+py_compile+回归全过；余 H3 会话绑定/H4 审核角色 待办 |
| R0.13 | H3 DPoP-lite 设备绑定 + H4 医生审核轻量加固 | 进行中 | H3: device_pubkeys 表 + Ed25519 持有证明 + JWT 绑定公钥 + X-PoP 校验 + REQUIRE_POP 渐进开关（默认关）；H4: approve 审计日志 + 限流 + HTTPS 告警 |
equestSubscribeMessage 参数按微信语义断言（规避 Taro 类型 entityIds 支付宝必填缺陷）；miniapp typecheck 15 error→0；全仓 5 包 typecheck 全绿 |
| T4.2b | PC Web 批量解析接真上传（presign/enqueue/confirm） | 已完成 | 真 API：presign→PUT→enqueue→轮询→confirm(deleteSource) |
| T2.6 | `GET /parse/jobs/:id` 补归属校验（getForUser） | 已完成 | 他人 jobId 返回 404 · tsc 通过 |
| T2.7 | Web 装依赖后跑 `tsc --noEmit` | 已完成 | 零 error · 顺带修复 api-client 重复方法（prd-v15-gaps） |
| T2.8 | 真机/模拟器 UI 回归（analyze 通过后） | 已完成 | Widget 回归全过（五 Tab/设置大字/语言/诊断）· 真机残留见 T2.4/T2.5 |
| T2.9 | 清理 info：`const FirebaseOptions` · Radio 弃用改 RadioGroup | 已完成 | analyze **No issues found** |
| T4.2a | T4.2 清单措辞：与真上传行为一致 | 已完成 | 已改为「真上传链路」描述 |
| SWIPER-R1 | swiper 12 override 运行时真机兼容（限期验证风险项） | 进行中 | 裁决（2026-10-26）：接受风险、不直接豁免；**owner：lead（协调）+ 真机执行人待指派；截止 2026-11-09**；矩阵/场景/回滚预案见 [audit-evidence/t05-build-and-swiper.md](audit-evidence/t05-build-and-swiper.md)；逾期未验立即上报裁决 |

**规范提醒**：任何新增工作（含审阅遗留、bugfix、文档）必须**同时**写入本清单（ID/任务/状态/验收），避免会话切换丢失。