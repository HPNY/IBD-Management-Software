# 肠安通 · IBD 病程管理 monorepo

基于 [PRD](docs/IBD病程管理程序PRD.md) 与 [架构分析](docs/compose/spec/architecture-techstack.md) 的 MVP 骨架。

## 结构

| 路径 | 说明 | MVP |
|------|------|-----|
| `services/api` | NestJS 模块化单体 + TypeORM(Postgres) | 是 |
| `services/parse-worker` | Python PDF 双引擎 Worker | 是 |
| `apps/mobile` | Flutter（占位） | 是 |
| `apps/miniapp` | Taro 小程序（占位） | 是 |
| `packages/domain-types` | 共享领域类型 | 是 |
| `apps/web` / `apps/doctor-web` | V1 / V2 | 否 |

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
- Parse Worker: 队列消费者（BullMQ `parse` 队列）
- Postgres: `5432` / Redis: `6379`
- 数据库：`DATABASE_URL`，骨架阶段 `DB_SYNC=true` 自动建表

无 Docker / 无 Postgres 时的实体层验收：

```bash
pnpm --filter @ibd/api smoke:entities   # pg-mem 内存库跑通 Lab/症状级联写入
```

无 Docker 时可分别运行：

```bash
pnpm --filter @ibd/api start:dev
# 另开终端
cd services/parse-worker && python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
python -m app.main
```
