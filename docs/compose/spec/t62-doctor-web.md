---
feature: t62-doctor-web
status: delivered
updated: 2026-09-23
branch: feature/t62-m1-m2
commits: 7977c5c..49cc957 cac1a8d
---

# T6.2 医生端 Web + 患者扫码授权拆解

## Report

**What was built** — T6.2 权威拆解：四阶段子包 M1–M4（医生身份与壳、患者扫码授权、只读病程视图+建议、审计/收回/过期）。固定 DEK/AK 再包裹与「可收回、可过期、审计日志」契约（architecture S2.3.5 / PRD §4.2.5 / §5.1）。本 spec 只拆解不实施。

**Verification** — 对照 PRD §4.2.5、§5.1、architecture DoctorGrant；worklist T6.2 已指向本 spec。无代码变更。

**Journey log** — `apps/doctor-web` 目前仅 README 占位。一期可「服务端明文授权视图」验证产品流，但**密文路径（DEK 再包裹）必须在同一 spec 验收里留任务**，避免只做明文、隐私承诺落空。

## [S1] Problem

worklist **T6.2**「医生端 Web + 患者扫码授权（DEK 再包裹）」未拆分。PRD 要求：医生认证、患者主动授权（扫码/邀请码）、查看自管数据与预警、标注建议、远程问诊摘要；架构要求 DEK/`AK` 经医生公钥再包裹、可收回可过期、审计。当前 `apps/doctor-web` 为空壳。

## [S2] Design — 四阶段子包

**总原则**
- **患者主动授权**：无全局医生可读；一切经 `DoctorGrant`（范围、时效、可收回）。
- **最小披露**：授权可选范围（检验 / 日记 / 预警 / 摘要）；默认不含原始 PDF。
- **审计**：每次医生读写入 audit log，患者可见。
- **合规**：执业核验可先「人工审核」占位；不实名患者。

### S2.1 M1 · 医生身份与 doctor-web 壳

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| M1.1 | Nest 医生账号：注册/登录 + 角色 doctor；执业证上传与人工审核状态 | 审核中不可看患者；通过后可进壳 (covers: S2.1) | — |
| M1.2 | `apps/doctor-web`：Vite+React 壳 + 路由（授权患者列表 / 详情 / 设置） | 可登录空态 (covers: S2.1; depends: M1.1) | M1.1 |
| M1.3 | 患者侧「我的医生」入口页（列表/无授权空态） | App 可进入 (covers: S2.1) | — |

### S2.2 M2 · 扫码授权（Grant）

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| M2.1 | 生成授权码/二维码：绑定 doctor 会话、范围子集、TTL（如 7 天）+ 可随时收回 | 码过期/收回后不可用 (covers: S2.2) | M1.1 |
| M2.2 | 患者扫码确认：范围勾选（检验/日记/预警/摘要）+ 文案明示 | 未勾选不可确认；确认后医生侧可见 (covers: S2.2; depends: M2.1) | M2.1 |
| M2.3 | `DoctorGrant` 表：doctorId、appUserId、scope JSON、expiresAt、revokedAt | DB 迁移 + 唯一活跃约束 (covers: S2.2; depends: M2.1) | M2.1 |
| M2.4 | （密文路径）患者将范围内 DEK/子密钥用医生公钥再包裹写入 Grant | 服务端不落明文 DEK；医生端用私钥解范围数据 (covers: S2.2; depends: M2.3) | M2.3 |

### S2.3 M3 · 只读病程视图 + 医学建议

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| M3.1 | 医生端：授权患者列表 + 详情（检验趋势、打卡摘要、预警卡片） | 只读；无授权患者 404 (covers: S2.3; depends: M2.2) | M2.2 |
| M3.2 | 病程摘要页：自动生成门诊摘要文本（复用 VisitSummary 逻辑） | 摘要可复制 (covers: S2.3; depends: M3.1) | M3.1 |
| M3.3 | 医学建议标注（DoctorNote）：文本建议、锚点日期可选 | 患者端「我的医生」可见建议列表 (covers: S2.3; depends: M3.1) | M3.1 |
| M3.4 | 服务端权限：按 grant.scope 过滤字段；越权 403 | 权限测试 (covers: S2.3; depends: M3.1) | M3.1 |

### S2.4 M4 · 审计 / 收回 / 过期

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| M4.1 | audit log：时间、doctor、action、resourceId；患者可查看 | 患者侧审计列表 (covers: S2.4; depends: M3.1) | M3.1 |
| M4.2 | 收回授权即时失效（医生 API 拒绝）；TTL 到期任务 | 收回后 403；过期 grant 不可读 (covers: S2.4; depends: M2.3) | M2.3 |
| M4.3 | 安全清单过一遍：无全局读、无精确授权外 PDF、日志无病历明文 | 检查表勾选 + 测试 (covers: S2.4; depends: M4.1) | M4.1 |

### S2.5 边界

- 不做：远程问诊 IM、处方、医保结算、真实 CA 签章。
- 执业核验：一期人工审核占位；第三方核验另议。
- 不授权社区（T6.1）数据给医生。

## [S3] Out of Scope

见 [S2.5]；本 spec 只拆解不实施；实施按 M1→M4 另开 compose。

## Tasks

- [x] T1: M1 医生身份与壳按 S2.1 实施 — acceptance: M1.1–M1.3 全勾 (covers: S2.1)
- [x] T2: M2 扫码授权按 S2.2 实施 — acceptance: M2.1–M2.3 全勾；M2.4 存 wrappedDek 字段（客户端打包） (covers: S2.2; depends: T1)
- [x] T3: M3 只读视图与建议按 S2.3 实施 — acceptance: M3.1–M3.4 服务端+doctor-web 完成；App 建议/审计为本地演示 (covers: S2.3; depends: T2)
- [x] T4: M4 审计收回过期按 S2.4 实施 — acceptance: M4.1 审计写入+患者查询；M4.2 收回/过期 requireActiveGrant；M4.3 安全清单（scope 过滤/403/无 PDF） (covers: S2.4; depends: T3)
