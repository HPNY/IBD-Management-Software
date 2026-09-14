# 配置与运维加固清单

基于对 README / compose / 依赖的审查整理。可与 [真机联调清单](device-test-checklist.md) 并行推进。

---

## P0 — 高（安全 / 可复现）

| # | 项 | 现状 | 验收 |
|---|-----|------|------|
| 1 | **`.env.example` 模板** | 无；变量散落在 README | 根目录 + `services/api` + `services/parse-worker` 各一份；按模块分组，标必需/默认 |
| 2 | **硬编码凭据下沉** | compose 中 MinIO/PG/S3 明文默认值 | `${MINIO_ROOT_USER}` 等从 env 读取；`.env.example` 给占位值；本地 `.env` 不入库 |
| 3 | **`DEV_SMS_CODE` 生产防护** | 默认 `123456` 可被误带到生产 | `NODE_ENV=production` 且仍为默认 → **拒绝启动** |
| 4 | **`DB_SYNC` 生产防护** | 仅文档警告 | `NODE_ENV=production && DB_SYNC=true` → 拒绝启动 |
| 5 | **Python 依赖锁定** | `requirements.txt` 非精确锁 | 引入 `requirements.in` + 锁定文件；CI 校验一致；PyMuPDF 等严格锁版本 |

## P1 — 中（工程化 / 上手）

| # | 项 | 现状 | 验收 |
|---|-----|------|------|
| 6 | **`docker-compose` 依赖解耦** | `parse-worker` `depends_on: api` | 仅依赖 `redis`（队列通信即可） |
| 7 | **`STORAGE_LOCAL_DIR` 双场景说明** | Docker `/data/uploads` vs 本机 `var/uploads` | README/configuration.md 写清；混合模式注意事项 |
| 8 | **集中配置文档** | 变量分散在多节 | `docs/configuration.md` 表格：模块/类型/默认/是否必需/生产注意 |
| 9 | **一键启动** | 多步手动 | `Makefile` 或 `scripts/dev.ps1`：`dev`（Docker）/ `dev-local`（无 Docker） |
| 10 | **`PUBLIC_BASE_URL` 生产校验** | 默认 `localhost` | production 且含 localhost → 警告或拒绝启动；`.env.example` 标「生产必须覆盖」 |

## P2 — 低（一致性）

| # | 项 | 现状 | 验收 |
|---|-----|------|------|
| 11 | **Node 精确版本** | `engines.node >=20` 过宽 | 根目录 `.nvmrc`（如 `20.18.0`）；可选 Volta 固定 node/pnpm |
| 12 | **`RUN_MIGRATIONS` 生产策略** | 容器启动自动跑 | production 改为独立 Job / 显式命令，避免滚动发布竞态 |
| 13 | **`STORAGE_SECRET` 默认值防护** | `dev-storage-secret` | 同 DEV_SMS_CODE：production 禁用默认值 |
| 14 | **README 去掉可复制的危险默认值** | 验证码等写在正文 | 迁到 `.env.example` 注释；README 只说「见 example」 |

---

## 建议执行顺序

```text
1) .env.example + compose 凭据变量化          → 消除明文密钥
2) 启动校验（DEV_SMS_CODE / DB_SYNC / PUBLIC_BASE_URL / STORAGE_SECRET）
3) requirements 锁定 + .nvmrc
4) compose depends_on 解耦 + configuration.md
5) Makefile / dev 脚本
6) production 迁移策略与文档收尾
```

## 与功能线的关系

| 线 | 文档 |
|----|------|
| 隐私与 App | [local-first](compose/spec/local-first.md) · [真机清单](device-test-checklist.md) |
| 功能 E2E | README「验证脚本」 |
| **本清单** | 环境、密钥、依赖、compose、生产校验 |

完成后应用侧仍可按真机清单联调；本清单不改业务逻辑，只收紧配置与启动约束。
