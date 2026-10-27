# 生产安全配置复查清单（Security Checklist）

- 任务号：T7 · 建立日期：2026-10-27 · 维护：每次部署前逐项复查
- 状态图例：✅ 代码已实现并验证 · ⬜ 部署时人工核对 · ⛔ 未实现/待办 · ⚠️ 部分实现
- 来源：R0.8–R0.13 安全加固轮 + T0.4 依赖治理 + 代码审计（var/prd-audit/services.md）

## 1. 环境与密钥（部署时核对）

| # | 检查项 | 验证方式 | 状态 |
|---|--------|---------|------|
| 1.1 | `JWT_SECRET` 为强随机值，非默认 | env-guard 启动拦截（`smoke:env`） | ✅ 逻辑 / ⬜ 部署值 |
| 1.2 | `STORAGE_SECRET` 非默认 | env-guard（生产拒绝默认） | ✅ / ⬜ |
| 1.3 | `DOCTOR_ADMIN_TOKEN` 强随机 + timing-safe 比较 | env-guard + R0.2 收紧 | ✅ / ⬜ |
| 1.4 | `NODE_ENV=production`；`DEV_SMS`/`DB_SYNC` 生产禁用 | env-guard 强制 | ✅ |
| 1.5 | 密钥不入库（Firebase/jks/pem/.env 已 gitignore） | `.gitignore`（M1）+ 推送前扫描 | ✅ |
| 1.6 | Redis `requirepass`；端口绑 127.0.0.1 | H5 加固 | ✅ 代码 / ⬜ 部署 |

## 2. 服务端防护

| # | 检查项 | 验证方式 | 状态 |
|---|--------|---------|------|
| 2.1 | CORS 显式白名单；生产禁用 Swagger | `main.ts`（H1） | ✅ |
| 2.2 | 多层限流（登录/上传/会话/推送/授权码/医生审核） | `rate-limit.ts`（H2/R0.10） | ✅ |
| 2.3 | X-Forwarded-For 默认不信任（`TRUSTED_PROXY` 显式开启） | R0.10 | ✅ |
| 2.4 | IDOR/归属校验（parse jobs、patients、grants、files） | R0.2/R0.3 审计 + smoke | ✅ |
| 2.5 | 文件上传：路径穿越防护 + 大小上限 20MB + PDF 魔数校验 | H7/R0.12 | ✅ |
| 2.6 | Skill 正则 ReDoS 防护（safe_re_search） | M5 | ✅ |
| 2.7 | SSRF 防护（拒绝 URL/绝对路径 objectKey） | H8 | ✅ |
| 2.8 | grant code 脱敏（确认后不回传）+ wrappedDek base64 校验 + 限流 | M3/M6 | ✅ |
| 2.9 | 医生审核：审计日志 + 限流 + HTTPS 告警 | H4 | ✅ |
| 2.10 | DPoP-lite 设备绑定（`REQUIRE_POP` 渐进开关，默认关） | H3 / ⚠️ 请求级验签待启用（R0.13 遗留） | ⚠️ |

## 3. 依赖与供应链

| # | 检查项 | 验证方式 | 状态 |
|---|--------|---------|------|
| 3.1 | CI 门禁：`pnpm audit --prod --audit-level=high` 必须为零 | CI 步骤（T0.4 裁决 2a） | ✅ |
| 3.2 | 全量审计遗留（dev 构建链 11 项）记录在案 | `docs/dependency-audit-notes.md` | ✅ |
| 3.3 | 锁文件冻结安装（`--frozen-lockfile`） | CI | ✅ |
| 3.4 | 工具链升级后门禁收紧回全量 high | T21（P1 后） | ⛔ |

## 4. 隐私与数据

| # | 检查项 | 验证方式 | 状态 |
|---|--------|---------|------|
| 4.1 | 推送/通知 payload 零病历字段（禁词表测试） | `reminder_copy_test` + push-copy smoke | ✅ |
| 4.2 | 日志不打印病历/检验/用药明细 | 代码审计 | ✅ |
| 4.3 | 云备份端到端密文（服务端仅存密文） | 代码审计 + sync smoke | ✅ |
| 4.4 | 解析原件"用完即删"（默认删除） | parse-source smoke + E2E | ✅ |
| 4.5 | 社区发布脱敏（白名单 + PII 值扫描） | skill-community smoke | ✅ |
| 4.6 | Web localStorage 敏感数据警示 | web README（M7） | ✅ |
| 4.7 | 非诊断/非治疗声明页面可见 | `DisclaimerFooter`×5 页（T7） | ✅ |
| 4.8 | DPIA/知情同意正式文本 | `docs/compliance/` 模板 | ⛔ 法务 BLOCKED |

## 5. 传输与存储

| # | 检查项 | 验证方式 | 状态 |
|---|--------|---------|------|
| 5.1 | HTTPS 全链路（含医生端） | 部署配置；医生审核接口有 HTTPS 告警 | ⬜ 部署核对 |
| 5.2 | App 本地库 SQLCipher（AES-256） | 代码审计 | ✅ |
| 5.3 | 会话令牌安全存储（Keystore/Keychain；旧 SharedPreferences 明文迁移删除） | token_store | ✅ |
| 5.4 | 字段级加密（DEK） | 目标设计未落地（PRD §4.1 如实记载） | ⛔ |

## 6. 授权边界

| # | 检查项 | 验证方式 | 状态 |
|---|--------|---------|------|
| 6.1 | 医生授权 scope 白名单 + 403 | scope guard + smoke | ✅ |
| 6.2 | 授权收回/过期强制执行 | requireActiveGrant | ✅ |
| 6.3 | 患者侧只回本人数据 | doctor-patient userId 过滤（T5 核实） | ✅ |
| 6.4 | 审计日志（医生查看/建议留痕） | doctor_audit_logs | ✅ |

## 部署前快速命令

```bash
pnpm audit --prod --audit-level=high        # 必须 0 high/critical
pnpm --filter @ibd/api smoke:env            # 生产配置守卫
pnpm --filter @ibd/api smoke:push-copy      # 推送文案隐私
pnpm --filter @ibd/api smoke:skill-community # 社区脱敏
python -m app.tests.test_lab_data_consistency # 检验数据一致性
```
