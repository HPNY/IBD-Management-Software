# 分支保护配置（硬规则 2 的落地方式）

- 任务号：T8.4
- 对应规则：**G0 未绿不合并**（[code-review-standard.md](code-review-standard.md) §7）
- 状态：**待仓库管理员执行**（此配置只能通过 GitHub 仓库设置开启，无法由仓库内文件自动生效）
- 一次性操作，约 5 分钟

---

## 1. 为什么必须单独配

硬规则 1（无任务号不开 PR）已经由 `.github/workflows/pr-guard.yml` 强制。
硬规则 2（G0 未绿不合并）**无法用仓库文件实现**——CI 跑绿只是"报告状态"，是否允许合并由 GitHub 的分支保护决定。不配这一项，任何人都能在红灯时点合并，规则形同虚设。

---

## 2. 必须开启的项

进入 **Settings → Branches → Add branch protection rule**，分支模式填 `main`。

| 配置项 | 取值 | 理由 |
|---|---|---|
| Require a pull request before merging | ✅ 开启 | 禁止直接 push main |
| ├ Required approvals | `0`（当前单人维护）→ 有第二人后改 `1` | 本仓库目前只有 1 名人类维护者，设 1 会永久卡死；改由 PR Guard + 自查证据代偿 |
| ├ Dismiss stale approvals when new commits are pushed | ✅ 开启 | 改代码后旧批准失效 |
| ├ Require review from Code Owners | ⬜ 暂不开 | 无 CODEOWNERS 文件 |
| **Require status checks to pass before merging** | ✅ 开启 | **本条即硬规则 2** |
| ├ Require branches to be up to date before merging | ✅ 开启 | 防止"基于旧 main 的绿"合并进新 main |
| **Do not allow bypassing the above settings** | ✅ 开启 | 关键项。否则管理员可随手绕过，规则退化为建议 |
| Require conversation resolution before merging | ✅ 开启 | 强制审查意见被回应，而非沉默通过 |
| Require linear history | ✅ 开启（squash 合并） | 与流程 §6「squash merge」一致 |
| Allow force pushes | ⬜ 关闭 | |
| Allow deletions | ⬜ 关闭 | |

---

## 3. Required status checks 填什么

必须与 `.github/workflows/` 中的 **job name** 完全一致（不是 workflow 名）。当前应勾选：

| Job name | 来源 | 检查内容 |
|---|---|---|
| `PR guard (任务号 / 描述完整性)` | `pr-guard.yml` | 硬规则 1 |
| `Lint (eslint + format + secrets)` | `ci.yml` | ESLint 0 error、变更文件格式、密钥扫描 |
| `Typecheck (all packages)` | `ci.yml` | 全 workspace 类型检查 |
| `API build & smoke` | `ci.yml` | API 构建 + 6 项冒烟 |
| `Parse worker unit` | `ci.yml` | Python 单测 |
| `Flutter analyze` | `ci.yml` | Flutter analyze + 全量测试 |
| `Fullstack E2E (Postgres+Redis)` | `ci-fullstack.yml` | 真实 Postgres/Redis 端到端 |

> 注意：`Fullstack E2E` 有 paths 过滤，只在改动 `services/**`、`apps/web/src/**` 等路径时触发。
> 若把它设为 required check，**未触发的 PR 会永久 pending**，无法合并。
> 处理方式二选一：
> - **推荐**：先在 GitHub 上确认该 check 的实际行为，若为 pending，则把它移出 required 列表，改由审查者在 PR 中确认「E2E 未触发，原因：未改服务端」；
> - 或去掉 `paths` 过滤，让它在所有 PR 上运行（代价是耗时增加）。
>
> 这是分支保护最常见的踩坑点，配置后**务必用一个测试 PR 验证一次**。

---

## 4. 验证方法

配置完成后，开一个测试分支做三件事，全部应被拦住：

1. **无任务号**：分支 `test/foo`、标题「测试」，PR Guard 应变红。
2. **红灯合并**：故意让 `pnpm lint` 失败（例如加一行 `const x: any = 1;` 并改坏格式），确认 GitHub 的 Merge 按钮变为不可用（显示 "Required status check is expected"）。
3. **直接 push main**：本地 `git push origin main`，应被拒绝（`protected branch hook declined`）。

三项都通过，硬规则 2 才算真正生效。

---

## 5. 如果开不了（私有仓库 + 免费计划）

GitHub 的分支保护对**私有仓库**需要 Pro/Team 及以上计划。若当前计划不支持，按以下降级方案执行，并在 `docs/session-worklist.md` 登记：

| 降级措施 | 说明 |
|---|---|
| 仓库转 Public | 若代码允许公开（本项目为医疗相关，需先做合规判断，**不得擅自转公开**） |
| 升级计划 | 推荐；成本低于一次数据事故 |
| 本地钩子代偿 | 加 `.git/hooks/pre-push` 拒绝直推 main（**仅对本机有效**，不防他人，不能替代分支保护） |
| 流程约束 | 由审查者在每次合并前手工核对「G0 全绿 + PR Guard 通过」，并在 PR 评论留痕 |

> 降级方案属于**流程约束**而非**机制约束**，其可靠性显著低于分支保护。若长期无法开启，应在月度复盘中把「门禁覆盖率」指标标注为不可信。

---

## 6. 与其它文档的关系

- 规则定义：[code-review-standard.md](code-review-standard.md) §7
- 流程步骤：[code-review-process.md](code-review-process.md) §4 步骤 6
- 检查项来源：[security-checklist.md](security-checklist.md)（部署态）、本文件（协作态）
