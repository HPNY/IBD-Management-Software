# IBDers

IBD（克罗恩病 / 溃疡性结肠炎）患者全病程自我管理应用。

**版本**：[v0.1.0](https://github.com/HPNY/IBD-Management-Software/releases/tag/v0.1.0) · **CI**：`main` 全绿  

**设计原则：医疗数据默认只存在你自己的手机上；未明确授权前不上传服务器。**

| 文档 | 说明 |
|------|------|
| [PRD](docs/IBD病程管理程序PRD.md) | 产品需求 |
| [架构分析](docs/compose/spec/architecture-techstack.md) | 技术栈与系统设计 |
| [本地优先改造](docs/compose/spec/local-first.md) | 隐私架构与分期 |
| [系统推送隐私边界](docs/push-privacy.md) | 本地通知保底 · 远程 opt-in · payload 白名单 |
| [设备联调清单](docs/device-test-checklist.md) | AVD / 真机验收 |
| [配置加固清单](docs/config-hardening-checklist.md) | 环境、密钥、依赖、CI |
| [配置说明](docs/configuration.md) | 全部环境变量与 `STORAGE_LOCAL_DIR` |

---

## 架构一览

```text
┌─────────────────────────────────────────────┐
│  Flutter App（个人终端）                      │
│  · app_user_uuid（本机生成，无强制登录）       │
│  · SQLCipher 加密本地库（Keystore 密钥）       │
│  · 病程数据全部本机读写；注射用本地通知        │
└───────────────┬─────────────────────────────┘
                │ 仅在用户明确同意时
                ▼
     ┌──────────────────────────────┐
     │  可选云端能力                   │
     │  ① 单次 PDF 解析 parse-session │
     │  ② 端到端密文备份 / 同步         │
     │  ③ Skill 模板（无病历明文）      │
     │  ④ 系统推送（opt-in·通用文案）   │
     └──────────────────────────────┘
```

| 模式 | 行为 |
|------|------|
| 默认 | 病程只在本机；无账号、无上传 |
| 解析 | 弹窗同意 → 短时 `parse-session` → 上传本次文件 → 结果写回本机 |
| 同步 | 设置中开启 + 备份口令 → AES-GCM 密文快照 → 服务端不可解密 |
| 推送 | 设置中开启 → 令牌只绑 `appUserId` → 通用提醒文案；可随时注销 |
| 换机 | 同 `appUserId` + 口令恢复；或导出/导入 JSON |
| 删云 | 一键删除云端密文副本 |

---

## 仓库结构

| 路径 | 说明 |
|------|------|
| `apps/mobile` | Flutter 主应用（本地优先，v0.1 功能见下） |
| `services/api` | NestJS：解析队列、密文同步、可选账号 |
| `services/parse-worker` | Python：Skill 模板 + LLM 兜底 |
| `packages/domain-types` | 共享领域类型 |
| `.github/workflows` | CI（smoke / E2E / flutter analyze） |
| `apps/miniapp` / `apps/web` / `apps/doctor-web` | 后续端（占位） |

---

## App 功能（v0.1 · 本地优先）

| 模块 | 能力 |
|------|------|
| **首页** | 仪表盘：今日管理、快捷入口、本机统计 |
| **打卡** | 症状日记：腹痛/排便次数/腹泻/Bristol/便血三级/紧迫感/黏液/恶心/疲劳/整体感受；保存后自动同步排便细表历史 |
| **注射** | 协议排期（Skyrizi 等）、时间轴、本地提醒、「今天已打」 |
| **分析** | 指标趋势 · 病程时间线 · 检查/手术 · 排便细表（含打卡同步记录）· 就诊摘要 · **发作预警** · **量表**（PHQ-9/IBDQ/MiniQoL） · **数据导出 CSV** · 系统通知测试 |
| **我的** | 应用 UUID、SQLCipher 状态、云同步/备份/导出、系统推送（opt-in）、AI 与提醒说明 |
| **检验** | 统一「录入检验」：套餐手填大项/小项；或同意上传报告解析，结果填入同一表单确认后写入本机 |
| **用药** | 当前方案、切换链、停药原因（可加密）、历史 |

底部导航：`首页 · 打卡 · 注射 · 分析 · 我的`

### 运行 App

```bash
# 模拟器 API 基址：http://10.0.2.2:3000
cd apps/mobile
pwsh ./bootstrap.ps1
flutter run --dart-define=IBD_API_BASE=http://10.0.2.2:3000
# 真机：http://<电脑局域网IP>:3000
```

断网可完成：录入检验、用药、注射排期、症状打卡、分析页浏览。

---

## 可选后端（解析 / 同步）

```bash
pnpm install
pnpm --filter @ibd/api build

export DATABASE_URL=postgres://ibd:ibd@127.0.0.1:5433/ibd
export REDIS_URL=redis://127.0.0.1:6380
export STORAGE_DRIVER=local
export STORAGE_LOCAL_DIR=var/uploads   # API 与 Worker 必须一致
export PUBLIC_BASE_URL=http://<电脑IP>:3000
export RUN_MIGRATIONS=true
export STORAGE_SECRET=<非默认>
export JWT_SECRET=<非默认>

pnpm --filter @ibd/api migration:run
node services/api/dist/main.js

# 另开：parse-worker
cd services/parse-worker
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.lock
PORT=8081 python -m app.main
```

一键（Windows）：

```powershell
pwsh ./scripts/dev.ps1           # 本机 Postgres/Redis
pwsh ./scripts/dev.ps1 -Docker   # 需先复制 .env.example → .env
```

或 `make dev` / `make dev-local`。变量说明：[docs/configuration.md](docs/configuration.md)。

| 服务 | 地址 |
|------|------|
| API | `http://localhost:3000` · Swagger `/docs` |
| Worker | `:8081` |
| 队列 | BullMQ `parse` |

### 关键 API（摘要）

| 能力 | 接口 |
|------|------|
| 解析/同步/推送短会话 | `POST /api/v1/auth/parse-session` · `sync-session` · `push-session` `{ appUserId }` |
| 密文同步 | `POST/GET/DELETE /api/v1/sync/ciphertext*` |
| 系统推送 | `POST/DELETE/GET /api/v1/push/devices` · `POST /api/v1/push/notify`（通用文案；未配 `FCM_*` 则 dry-run） |
| 解析 | `POST /api/v1/parse/jobs` · `POST /:id/confirm`（Skill 入库） |
| 直传 | `POST /api/v1/files/presign` → `PUT uploadUrl` |
| 可选账号关联（非登录） | `POST /api/v1/auth/login`（为关联手机号预留；开发验证码 `123456`，**勿用于生产**） |
| 用药/注射 | Swagger：切换链、协议排期、到期提醒 |

### LLM（可选）

未配置时：Skill 未命中 → 建议手动录入。配置后走 OpenAI 兼容 API。

| 环境变量 | 说明 |
|----------|------|
| `LLM_API_BASE` | 兼容网关 |
| `LLM_API_KEY` | Key |
| `LLM_MODEL` | 默认 `gpt-4o-mini` |

---

## 验证与 CI

```bash
pnpm --filter @ibd/api smoke:env
pnpm --filter @ibd/api smoke:entities
pnpm --filter @ibd/api smoke:migration
pnpm --filter @ibd/api smoke:storage
pnpm --filter @ibd/api smoke:push-copy
pnpm --filter @ibd/api e2e:fullstack
pnpm --filter @ibd/api e2e:injection
pnpm --filter @ibd/api e2e:medication
cd services/parse-worker && python -m app.tests.test_ai_engine
# 备份 + 解析链路
node services/api/scripts/e2e-backup-ai.mjs
```

| Workflow | 内容 |
|----------|------|
| `ci.yml` | Node/pnpm build + typecheck + smoke · Python AI 单测 · `flutter analyze`（info 不阻塞） |
| `ci-fullstack.yml` | Postgres+Redis + `scripts/ci-fullstack.sh`：e2e fullstack / injection / medication / backup-ai |

Actions：https://github.com/HPNY/IBD-Management-Software/actions  

---

## 安全说明

- 本地库 **SQLCipher**，密钥在 Android Keystore / iOS Keychain  
- 云备份 AES-GCM + PBKDF2（备份口令 + appUserId），服务端仅 cipher / nonce / mac  
- 解析上传必须用户点「同意」；`parse-session` 约 30 分钟过期  
- 系统推送 opt-in：令牌只绑 `app_user_uuid`；payload 仅通用文案，无药品/剂量/病历（[边界说明](docs/push-privacy.md)）  
- 卸载重装会丢本机密钥 → 先导出 JSON 或上传加密快照  
- 生产环境：`DEV_SMS_CODE` / 默认密钥 / `DB_SYNC=true` / `PUBLIC_BASE_URL` 含 localhost → **拒绝启动**（见 `env-guard`）

---

## 里程碑

| 标签 | 内容 |
|------|------|
| **v0.1.0** | 本地优先 MVP：检验/用药/注射/打卡、SQLCipher、解析+Skill、密文同步、UI 仪表盘与五 Tab、分析页（趋势/时间线/检查手术/排便/摘要/发作预警）、CI 全绿 |

后续：真机验收、微信小程序、PC Web、医生端、量表等（见 [配置加固清单](docs/config-hardening-checklist.md) 与会话工作清单）。系统推送（本地保底 + FCM opt-in）见 [push-privacy](docs/push-privacy.md)。

---

## 许可与贡献

个人医疗数据项目；默认本地、最小上传。欢迎 Issue / PR。
