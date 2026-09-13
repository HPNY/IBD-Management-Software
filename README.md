# 肠安通 · IBD 病程管理 monorepo

基于 [PRD](docs/IBD病程管理程序PRD.md) 与 [架构分析](docs/compose/spec/architecture-techstack.md) 的 MVP 骨架。

## 结构

| 路径 | 说明 | MVP |
|------|------|-----|
| `services/api` | NestJS 模块化单体 + TypeORM(Postgres) + Object Storage | 是 |
| `services/parse-worker` | Python PDF 双引擎 Worker | 是 |
| `apps/mobile` | Flutter（占位） | 是 |
| `apps/miniapp` | Taro 小程序（占位） | 是 |
| `packages/domain-types` | 共享领域类型 | 是 |
| `apps/web` / `apps/doctor-web` | V1 / V2 | 否 |

## 直传（Object Storage）

1. `POST /api/v1/files/presign` `{ filename, contentType }` → `{ objectKey, uploadUrl, method:"PUT" }`
2. 客户端对 `uploadUrl` 发 PUT 上传文件
3. `POST /api/v1/parse/jobs` `{ objectKey, hospitalHint, reportType }` 入队解析

驱动：

- `STORAGE_DRIVER=local`（默认）：HMAC 签名后 PUT 到 API；文件在 `STORAGE_LOCAL_DIR`
- `STORAGE_DRIVER=s3`：MinIO / OSS（S3 兼容）预签名；需 `S3_ENDPOINT` / `S3_BUCKET` / 密钥

compose 已带 MinIO（`9000/9001`）；`STORAGE_DRIVER=s3 docker compose up` 可切到对象存储。

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
- 数据库：`DATABASE_URL`，骨架阶段 `DB_SYNC=true` 自动建表
- 队列：`REDIS_URL`；`PARSE_QUEUE` 默认 `parse`

无 Docker / 无 Postgres 时的实体层验收：

```bash
pnpm --filter @ibd/api smoke:entities   # pg-mem 内存库跑通 Lab/症状级联写入
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

无 Docker 时可分别运行：

```bash
pnpm --filter @ibd/api start:dev
# 另开终端
cd services/parse-worker && python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
python -m app.main
```
