# 肠安通 · IBD 病程管理 monorepo

基于 [PRD](docs/IBD病程管理程序PRD.md) 与 [架构分析](docs/compose/spec/architecture-techstack.md) 的 MVP 骨架。

## 结构

| 路径 | 说明 | MVP |
|------|------|-----|
| `services/api` | NestJS 模块化单体 + TypeORM(Postgres) + Object Storage | 是 |
| `services/parse-worker` | Python PDF 双引擎 Worker（Skill + AI/LLM） | 是 |
| `apps/mobile` | Flutter（直传解析页已实现） | 是 |
| `apps/miniapp` | Taro 小程序（占位） | 是 |
| `packages/domain-types` | 共享领域类型 | 是 |
| `apps/web` / `apps/doctor-web` | V1 / V2 | 否 |

## 登录（JWT）

- `POST /api/v1/auth/login` `{ phone, code }` — 开发验证码默认 `123456`（`DEV_SMS_CODE`）
- 返回 `accessToken`（15m）+ `refreshToken`（30 天，轮转）
- `POST /auth/refresh` / `POST /auth/logout` / `GET /auth/me`
- 业务 API 全局 `JwtAuthGuard`；`@Public()` 仅 health、login/refresh/logout、`PUT /files/upload`（HMAC）

```bash
curl -X POST :3000/api/v1/auth/login \
  -H 'content-type: application/json' \
  -d '{"phone":"13800000000","code":"123456"}'
```

## AI 解析（LLM 兜底）

Skill 未命中时走 OpenAI 兼容接口：

| 环境变量 | 说明 |
|----------|------|
| `LLM_API_BASE` | 如 `https://api.openai.com/v1` 或兼容网关 |
| `LLM_API_KEY` | API Key |
| `LLM_MODEL` | 默认 `gpt-4o-mini` |
| `LLM_TIMEOUT_SEC` | 默认 60 |

无配置时降级为空结果（客户端手动录入）。单测：

```bash
cd services/parse-worker && python -m app.tests.test_ai_engine
```

## 直传（Object Storage）

1. `POST /api/v1/files/presign` `{ filename, contentType }` → `{ objectKey, uploadUrl, method:"PUT" }`
2. 客户端对 `uploadUrl` 发 PUT 上传文件
3. `POST /api/v1/parse/jobs` `{ objectKey, hospitalHint, reportType }` 入队解析

驱动：

- `STORAGE_DRIVER=local`（默认）：HMAC 签名后 PUT 到 API；文件在 `STORAGE_LOCAL_DIR`
- `STORAGE_DRIVER=s3`：MinIO / OSS（S3 兼容）预签名；需 `S3_ENDPOINT` / `S3_BUCKET` / 密钥

compose 已带 MinIO（`9000/9001`）；`STORAGE_DRIVER=s3 docker compose up` 可切到对象存储。

Flutter 端直传入口见 `apps/mobile/README.md`（`ParseUploadPage`）。

## 本地启动

```bash
# 需要 Node 20+、pnpm、Python 3.11+、Docker
pnpm install
pnpm --filter @ibd/api build
docker compose up --build
```

服务：

- API: `http://localhost:3000` 健康检查 `GET /health`（含 db 探活）
- Swagger: `http://localhost:3000/docs`
- Parse Worker: BullMQ 队列 `parse`，job 名 `parsePdf`；完成后由 API `QueueEvents` 回写 `parse_jobs`
- Postgres: `5432` / Redis: `6379`（BullMQ 需 Redis ≥5，建议 ≥6.2）
- 数据库：`DATABASE_URL`；**默认 migrations**（启动 `RUN_MIGRATIONS=true` 自动执行）；仅调试可用 `DB_SYNC=true`（勿用于生产）
- 队列：`REDIS_URL`；`PARSE_QUEUE` 默认 `parse`

### Migrations

```bash
pnpm --filter @ibd/api migration:show
pnpm --filter @ibd/api migration:run
pnpm --filter @ibd/api migration:revert
# 改实体后生成增量迁移
pnpm --filter @ibd/api migration:generate src/database/migrations/AlterXxx
```

初始迁移：`src/database/migrations/1726200000000-InitSchema.ts`

无 Docker / 无 Postgres 时的实体层验收：

```bash
pnpm --filter @ibd/api smoke:entities   # pg-mem 内存库跑通 Lab/症状级联写入
pnpm --filter @ibd/api smoke:migration  # InitSchema raw SQL 建表 + 关联插入
```

BullMQ 契约冒烟（需本机 Redis）：

```bash
# 起 worker 后另开终端
REDIS_URL=redis://127.0.0.1:6379 node services/api/scripts/queue-smoke.mjs
# 直传 objectKey + worker 取件
REDIS_URL=redis://127.0.0.1:6379 node services/api/scripts/storage-queue-smoke.mjs
```

本地 storage 单元冒烟：

```bash
pnpm --filter @ibd/api smoke:storage
```

### 全栈联调（无 Docker 时）

依赖：Postgres + Redis（端口示例 `5433` / `6380`）。

```bash
export DATABASE_URL=postgres://ibd:ibd@127.0.0.1:5433/ibd
export REDIS_URL=redis://127.0.0.1:6380
export STORAGE_DRIVER=local
export STORAGE_LOCAL_DIR=var/uploads
export PUBLIC_BASE_URL=http://127.0.0.1:3000
export RUN_MIGRATIONS=true

pnpm --filter @ibd/api migration:run
pnpm --filter @ibd/api build
# 终端 A
node services/api/dist/main.js
# 终端 B（勿继承 PORT=3000）
cd services/parse-worker && PORT=8081 python -m app.main
# 终端 C
pnpm --filter @ibd/api e2e:fullstack
```

E2E 会走通：health → presign → PUT → parse/jobs → worker Skill 解析 → 确认写入 labs。

无 Docker 时可分别运行：

```bash
pnpm --filter @ibd/api start:dev
# 另开终端
cd services/parse-worker && python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
python -m app.main
```
