---
feature: c-hardening
status: delivered
updated: 2026-09-23
branch: feature/c-hardening
commits: 4aca0ca..HEAD
---

# C 组安全加固与 API 接线

## Report

**What was built** — C 组安全加固：TokenStore/备份口令入 Keystore+迁移明文；geo/drug 伪匿名改 SHA-256-16hex；Web appUserId 用 crypto 随机；移动端 `_send` 支持 PATCH；药物评价聚合优先走 `/drug-reviews/summary` 失败回落本地。

**Verification** — `@ibd/api` typecheck PASS；`@ibd/web` typecheck PASS；`flutter test` PASS 97。

**Journey log** — secure storage 需保留 legacy 迁移否则老用户丢 token。伪匿名字段名保持 raterHash 兼容表结构。

## [S1] Problem

全库二次审查留下安全与接线残留：Refresh token / 备份口令明文 SharedPreferences；FNV-32 伪匿名可碰撞；Web `appUserId` 时间戳可预测；api-client 不支持 PATCH；App 侧 D2/M2 等仍为本地骨架未接真实 API。需一次加固并接线，降低伪造身份与本地泄露风险。

## [S2] Design

### S2.1 敏感凭证入安全存储

- `TokenStore`（access/refresh）与 `BackupService` 口令改用 `flutter_secure_storage`（对齐 `db_key_service` 的 Android encryptedSharedPreferences）。
- 读取兼容：secure 无值时回读一次 SharedPreferences 并迁移，成功后删除明文键。
- 验收：保存/读取 roundtrip；明文键迁移后不再保留。

### S2.2 伪匿名哈希

- 服务端 `pseudoHash`（geo/drug）改为 SHA-256 截断 16 hex（`node:crypto`）。
- 命名改为 `pseudonymId` 语义（字段仍 `raterHash`/`authorHash` 以兼容表）。
- 验收：smoke 断言同输入稳定、异输入碰撞空间显著大于 32-bit。

### S2.3 Web 身份随机

- `ParseBatch` / 本地 `appUserId` 改为 `crypto.getRandomValues` 128-bit hex（`web-<32hex>`）。
- 验收：格式断言；不再使用 `Date.now()`。

### S2.4 api-client PATCH

- `IbdApiClient._send` 支持 `PATCH`；`updateMedication` 可调用。
- 验收：typecheck + 方法存在。

### S2.5 App 接线（能接则接）

- M2：`my_doctors_page` 确认/列表/收回走 `api-client`（失败降级本地演示并提示）。
- D2：药物评价「社区聚合」优先拉 `/drug-reviews/summary`，失败用 `aggregateLocal`。
- 验收：有网路径调用 API；离线/失败有明确提示，不崩溃。

## [S3] Out of Scope

- 生物解锁、助记词托管、root 检测
- 完整 API 集成测试基建（jest/e2e）
- VisitSummary 全量移植、D4 日历窗口（增强项另议）

## Tasks

- [x] T1: TokenStore/备份口令 secure storage + 迁移 — acceptance: 无明文 refresh/口令残留 (covers: S2.1)
- [x] T2: SHA-256 伪匿名 + smoke — acceptance: smoke PASS (covers: S2.2)
- [x] T3: Web appUserId 随机 — acceptance: 无 Date.now 身份 (covers: S2.3)
- [x] T4: api-client PATCH — acceptance: typecheck PASS (covers: S2.4)
- [x] T5: App 接线 M2/D2 API 降级 — acceptance: 有网调用、失败降级 (covers: S2.5)
