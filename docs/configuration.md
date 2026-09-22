# 配置说明（IBDers）

所有环境变量模板见：

- 根目录 [`.env.example`](../.env.example) — Docker Compose 基础设施  
- [`services/api/.env.example`](../services/api/.env.example)  
- [`services/parse-worker/.env.example`](../services/parse-worker/.env.example)  

**将 `.env.example` 复制为 `.env` 后修改；`.env` 已被 gitignore。**

---

## 1. 认证（services/api）

| 变量 | 类型 | 默认 | 必需 | 说明 |
|------|------|------|------|------|
| `JWT_SECRET` | string | `dev-jwt-secret-change-me` | 生产必填 | 非默认；production 默认值 → 拒绝启动 |
| `JWT_ACCESS_TTL` | string | `15m` | 否 | Access Token 有效期 |
| `JWT_REFRESH_TTL_DAYS` | number | `30` | 否 | Refresh 有效期（天） |
| `DEV_SMS_CODE` | string | `123456` | 开发用 | **仅 development**；production 使用默认/过短 → 拒绝启动 |

---

## 2. 数据库

| 变量 | 类型 | 默认 | 必需 | 说明 |
|------|------|------|------|------|
| `DATABASE_URL` | URL | `postgres://ibd:ibd@localhost:5432/ibd` | 是 | 弱口令在 production 仅告警 |
| `DB_SYNC` | bool | `false` | 否 | TypeORM synchronize；**production 禁止 true** |
| `DB_MIGRATIONS_RUN` | bool | `false` | 否 | CLI 用；API 用 `RUN_MIGRATIONS` |
| `DB_LOGGING` | bool | `false` | 否 | SQL 日志 |
| `RUN_MIGRATIONS` | bool | 开发 `true` / 生产默认不跑 | 否 | 生产建议独立 Job 显式执行 |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | string | — | Compose | compose 要求设置密码 |

---

## 3. 队列

| 变量 | 类型 | 默认 | 必需 | 说明 |
|------|------|------|------|------|
| `REDIS_URL` | URL | `redis://localhost:6379` | 是 | BullMQ；建议 Redis ≥ 6.2 |
| `PARSE_QUEUE` | string | `parse` | 否 | 队列名（API/Worker 需一致） |
| `PARSE_CONCURRENCY` | number | `2` | 否 | Worker 并发 |

---

## 4. 对象存储 / 直传

| 变量 | 类型 | 默认 | 必需 | 说明 |
|------|------|------|------|------|
| `STORAGE_DRIVER` | `local` \| `s3` | `local` | 否 | local：HMAC PUT 到 API；s3：预签名 |
| `STORAGE_LOCAL_DIR` | path | `var/uploads`（本机） | local 必填 | **见下方双场景** |
| `STORAGE_SECRET` | string | `dev-storage-secret` | 生产必填 | production 默认值 → 拒绝启动 |
| `PUBLIC_BASE_URL` | URL | `http://localhost:3000` | 生产必填 | 预签名/上传基址；production 禁止 localhost |
| `S3_ENDPOINT` | URL | — | s3 时 | MinIO/OSS |
| `S3_BUCKET` | string | `ibd-uploads` | s3 时 | |
| `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` | string | — | s3 时 | compose 从 `MINIO_ROOT_*` 注入 |
| `S3_FORCE_PATH_STYLE` | bool | `true` | s3 时 | MinIO 常用 |
| `S3_REGION` | string | `us-east-1` | s3 时 | |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | string | — | Compose MinIO | **勿写死在 yml** |

### `STORAGE_LOCAL_DIR` 双场景

| 场景 | 推荐值 | 说明 |
|------|--------|------|
| **Docker Compose** | `/data/uploads` | API 与 Worker 共享卷 `uploads:/data/uploads` |
| **本机（无 Docker）** | `<repo>/var/uploads` | **API 与 Worker 必须同一绝对/相对可见路径**；Worker 工作目录不同会找不到文件 |
| 混合（API 在 Docker、Worker 本机） | 不推荐 | 需挂载同一宿主机目录，否则「已上传但 Worker 读不到」 |

生成预签名时 `PUBLIC_BASE_URL` 必须是**客户端可访问**的地址（真机用电脑局域网 IP，不是 `127.0.0.1`）。

---

## 5. LLM（parse-worker，可选）

| 变量 | 类型 | 默认 | 必需 | 说明 |
|------|------|------|------|------|
| `LLM_API_BASE` | URL | 空 | 否 | 空则 Skill 未命中时降级手动录入 |
| `LLM_API_KEY` | string | 空 | 有 base 时 | |
| `LLM_MODEL` | string | `gpt-4o-mini` | 否 | |
| `LLM_TIMEOUT_SEC` | number | `60` | 否 | |

---

## 5b. FCM 推送（services/api，可选）

**未配置任何 `FCM_*` 时 dry-run**（只记日志，不访问 Google）。payload 仅通用文案，详见 [push-privacy](push-privacy.md)。

| 变量 | 类型 | 默认 | 必需 | 说明 |
|------|------|------|------|------|
| `FCM_SERVER_KEY` | string | 空 | 否 | 传统 FCM API；与服务账号二选一 |
| `FCM_PROJECT_ID` | string | 空 | 服务账号方式 | Firebase 项目 ID |
| `FCM_CLIENT_EMAIL` | string | 空 | 服务账号方式 | 服务账号邮箱 |
| `FCM_PRIVATE_KEY` | string | 空 | 服务账号方式 | PEM 私钥；`.env` 中可用 `\n` 转义 |

配置齐备后 `POST /api/v1/push/notify` 才真实发送；否则返回 `dryRun: true`。

短时会话与设备注册有进程内限流（约 20–30 次/分钟/键）；多实例部署请改用 Redis 或网关限流。

---

## 6. 服务端口

| 变量 | 默认 | 说明 |
|------|------|------|
| `PORT` | API `3000` / Worker `8081` | Worker **勿继承 API 的 PORT** |

---

## 7. 生产启动校验（env-guard）

`NODE_ENV=production` 时以下情况 **拒绝启动**：

- `DEV_SMS_CODE` 为 `123456`/`dev` 或长度 &lt; 6  
- `DB_SYNC=true`  
- `STORAGE_SECRET` 缺失或为 `dev-storage-secret`  
- `JWT_SECRET` 缺失或为默认  
- `PUBLIC_BASE_URL` 缺失或含 `localhost` / `127.0.0.1`  

本地验证：

```bash
pnpm --filter @ibd/api smoke:env
```

---

## 8. 一键脚本

```powershell
# Windows
pwsh ./scripts/dev.ps1          # 本机 Postgres/Redis 假设已就绪
pwsh ./scripts/dev.ps1 -Docker  # docker compose up
```

或 `make dev` / `make dev-local`（见根目录 Makefile）。
