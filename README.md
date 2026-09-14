# IBDers

IBD（克罗恩病 / 溃疡性结肠炎）患者全病程自我管理应用。

**设计原则：医疗数据默认只存在你自己的手机上；未明确授权前不上传服务器。**

| 文档 | 说明 |
|------|------|
| [PRD](docs/IBD病程管理程序PRD.md) | 产品需求 |
| [架构分析](docs/compose/spec/architecture-techstack.md) | 技术栈与系统设计 |
| [本地优先改造](docs/compose/spec/local-first.md) | 隐私架构与分期 |
| [真机联调清单](docs/device-test-checklist.md) | 设备验证步骤 |
| [配置加固清单](docs/config-hardening-checklist.md) | 环境变量 / 密钥 / 依赖 / 生产校验 |

---

## 架构一览

```text
┌─────────────────────────────────────────────┐
│  Flutter App（个人终端）                      │
│  · app_user_uuid（本机生成，无强制登录）       │
│  · SQLCipher 加密本地库（Keystore 密钥）       │
│  · 检验 / 用药 / 注射 / 症状 全部本机读写      │
│  · 注射提醒：本地通知                        │
└───────────────┬─────────────────────────────┘
                │ 仅在用户明确同意时
                ▼
     ┌──────────────────────────────┐
     │  可选云端能力                   │
     │  ① 单次 PDF 解析（parse-session）│
     │  ② 端到端密文备份/同步           │
     │  ③ Skill 模板（无病历明文）      │
     └──────────────────────────────┘
```

| 模式 | 行为 |
|------|------|
| 默认 | 病程只在本机；无账号、无上传 |
| 解析 | 弹窗同意 → 短时 `parse-session`（30 分钟）→ 上传本次文件 → 结果写回本机 |
| 同步 | 设置里开启 + 备份口令 → AES-GCM 密文快照 → 服务端不可解密 |
| 换机 | 同 `appUserId` + 口令 → 从云端恢复；或导出/导入 JSON |
| 删云 | 一键删除云端密文副本 |

---

## 仓库结构

| 路径 | 说明 |
|------|------|
| `apps/mobile` | Flutter 主应用（本地优先） |
| `services/api` | NestJS：解析队列、密文同步、可选账号 |
| `services/parse-worker` | Python：Skill 模板 + LLM 解析 Worker |
| `packages/domain-types` | 共享领域类型 |
| `apps/miniapp` / `apps/web` / `apps/doctor-web` | 后续端（占位） |

---

## App 功能（本地）

| 功能 | 说明 |
|------|------|
| 检验 | 手动录入；或「同意上传」后云端解析再写回本机 |
| 用药 | 当前方案、停药原因、历史；服务端另有切换链/副作用 API |
| 注射 | 本地协议生成排期（Skyrizi 等），本地通知提醒，可记「今天已打」 |
| 症状 | 每日打卡（腹痛/腹泻/Bristol 等） |
| 隐私 | 应用 UUID、同步开关、SQLCipher 状态、导出/导入、删云端 |

### 运行 App

```bash
cd apps/mobile
pwsh ./bootstrap.ps1   # 需要 Flutter SDK；生成 android/ios 工程
flutter run --dart-define=IBD_API_BASE=http://<电脑局域网IP>:3000
```

断网可完成：录入检验、用药、注射排期、症状打卡。

---

## 可选后端（解析 / 同步）

```bash
# 需要 Node 20+、pnpm、Python 3.11+、Postgres、Redis
pnpm install
pnpm --filter @ibd/api build

export DATABASE_URL=postgres://ibd:ibd@127.0.0.1:5433/ibd
export REDIS_URL=redis://127.0.0.1:6380
export STORAGE_DRIVER=local
export STORAGE_LOCAL_DIR=var/uploads
export PUBLIC_BASE_URL=http://<电脑IP>:3000
export RUN_MIGRATIONS=true

pnpm --filter @ibd/api migration:run
node services/api/dist/main.js

# 另开终端
cd services/parse-worker
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
PORT=8081 python -m app.main
```

Docker：`docker compose up --build`（Postgres / Redis / MinIO / API / Worker）。

| 服务 | 地址 |
|------|------|
| API | `http://localhost:3000` · Swagger `/docs` |
| Worker | `:8081` |
| 队列 | BullMQ `parse` |

### 关键 API（摘要）

| 能力 | 接口 |
|------|------|
| 短时解析会话 | `POST /api/v1/auth/parse-session` `{ appUserId }` |
| 短时同步会话 | `POST /api/v1/auth/sync-session` `{ appUserId }` |
| 密文同步 | `POST/GET/DELETE /api/v1/sync/ciphertext*` |
| 解析任务 | `POST /api/v1/parse/jobs` · `POST /:id/confirm` |
| 文件直传 | `POST /api/v1/files/presign` → `PUT uploadUrl` |
| 可选账号登录 | `POST /api/v1/auth/login`（开发验证码 `123456`） |
| 用药/注射 | 见 Swagger：切换链、协议排期、到期提醒 |

### 验证脚本

```bash
pnpm --filter @ibd/api smoke:entities
pnpm --filter @ibd/api smoke:migration
pnpm --filter @ibd/api smoke:storage
pnpm --filter @ibd/api e2e:fullstack
pnpm --filter @ibd/api e2e:injection
pnpm --filter @ibd/api e2e:medication
cd services/parse-worker && python -m app.tests.test_ai_engine
```

### LLM（Skill 未命中时）

| 环境变量 | 说明 |
|----------|------|
| `LLM_API_BASE` | OpenAI 兼容网关 |
| `LLM_API_KEY` | API Key |
| `LLM_MODEL` | 默认 `gpt-4o-mini` |

---

## 安全说明

- 本地库：**SQLCipher**，密钥在 Android Keystore / iOS Keychain  
- 云备份：AES-GCM + PBKDF2（备份口令 + appUserId），服务端只存 cipher/nonce/mac  
- 解析上传：必须用户点击「同意」；会话 30 分钟过期  
- 卸载重装会丢本机密钥 → 请事先导出 JSON 或上传加密快照  

---

## 许可与贡献

个人医疗数据项目；默认本地、最小上传。欢迎 Issue / PR。
