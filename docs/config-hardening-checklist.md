# 配置与运维加固清单

基于对 README / compose / 依赖的审查整理。可与 [真机联调清单](device-test-checklist.md) 并行推进。

---

## P0 — 高（安全 / 可复现）— 已完成

- [x] **1 `.env.example`** — 根 + `services/api` + `services/parse-worker`
- [x] **2 硬编码凭据下沉** — compose 使用 `${POSTGRES_PASSWORD:?}` / `${MINIO_ROOT_USER:?}` 等
- [x] **3 `DEV_SMS_CODE` 生产防护** — `services/api/src/config/env-guard.ts` 拒绝启动
- [x] **4 `DB_SYNC` 生产防护** — production + true → 拒绝启动
- [x] **5 Python 依赖锁定** — `requirements.in` + `requirements.txt` / `requirements.lock` 精确 pin

验证：`pnpm --filter @ibd/api smoke:env` → ALL_PASS

## P1 — 中（工程化 / 上手）

- [x] **6 compose 依赖解耦** — `parse-worker` 仅 `depends_on: redis`
- [ ] **7 `STORAGE_LOCAL_DIR` 双场景说明** — Docker `/data/uploads` vs 本机 `var/uploads`
- [ ] **8 集中配置文档** — `docs/configuration.md`
- [ ] **9 一键启动** — `Makefile` 或 `scripts/dev.ps1`
- [x] **10 `PUBLIC_BASE_URL` 生产校验** — env-guard 禁止 localhost/127.0.0.1

## P2 — 低（一致性）

- [x] **11 Node 精确版本** — 根目录 `.nvmrc` = `20.18.0`
- [x] **12 `RUN_MIGRATIONS` 生产策略** — production 默认不自动跑，需显式 `true`
- [x] **13 `STORAGE_SECRET` 默认值防护** — env-guard
- [ ] **14 README 去掉可复制的危险默认值** — 验证码等改由 `.env.example` 承载

---

## 建议执行顺序（剩余）

```text
7) configuration.md（含 STORAGE_LOCAL_DIR 双场景）
8) Makefile / scripts/dev.ps1
9) README 清理危险默认值示例
```

## 与功能线的关系

| 线 | 文档 |
|----|------|
| 隐私与 App | [local-first](compose/spec/local-first.md) · [真机清单](device-test-checklist.md) |
| 功能 E2E | README「验证脚本」 |
| **本清单** | 环境、密钥、依赖、compose、生产校验 |
