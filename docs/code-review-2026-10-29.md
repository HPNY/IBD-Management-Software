# IBD Management Software 代码审阅报告

- **审阅日期**：2026-10-29
- **审阅对象**：`main` 分支 `c0eb9fe`（工作区干净，审阅期间未修改任何源码）
- **范围**：`apps/mobile`（Flutter，≈16k 行）、`services/api`（NestJS，≈7k 行）、`services/parse-worker`（Python）、`apps/web` / `apps/doctor-web` / `apps/miniapp`、`packages/*`、根级配置 / CI / 脚本，合计约 26k 行
- **结论（先行）**：**存在 Bug，且其中若干会直接造成医疗数据丢失、隐私泄露或核心功能不可用。** 详见下方 Critical / High 清单。

---

## 一、审阅方法与基线

### 1.1 分工

6 个并行审阅者按区域通读全部源码，Lead 负责跨层复核、可执行验证与汇总：

| 区域 | 范围 | 行数 | 报告 |
|---|---|---|---|
| API 安全核心 | auth / sync / storage / config / common / database | ≈2.9k | [api-core.md](var/review/api-core.md) |
| API 业务模块 | parse / push / medication / injection / lab / symptom / reminder / doctor / skill / patient / geo-community / drug-review | ≈4.2k | [api-modules.md](var/review/api-modules.md) |
| Flutter 核心层 | `lib/core/**` + `main.dart` + 全部 38 个测试 + tool | ≈9.4k | [mobile-core.md](var/review/mobile-core.md) |
| Flutter 功能层 | `lib/features/**` | ≈9.7k | [mobile-features.md](var/review/mobile-features.md) |
| 解析服务 + 辅助前端 | parse-worker、web、doctor-web、miniapp、packages | ≈3.3k | [worker-web.md](var/review/worker-web.md) |
| 基础设施 / CI / 配置 / 文档一致性 | compose、Dockerfile、workflows、scripts、env、README/docs | — | [infra.md](var/review/infra.md) |

### 1.2 验证手段（不只是"读代码"）

已执行并通过的客观基线（即：**现有测试全绿，说明这些问题都没被测出来**）：

- `tsc --noEmit`：api / web / doctor-web / domain-types 全部 0 错误；
- API 冒烟：`env-guard`、`storage`、`push-copy`、`parse-source`、`pseudonym`、`doctor-scope`、`visit-summary`、`skill-community-scrub`、`entity`、`migration` 全部 PASS；
- parse-worker 单测：`test_ai_engine` ALL_PASS、`test_lab_data_consistency` OK；
- 用 `pg-mem` + TypeORM 0.3.31 实际复现了 3 个 ORM 语义陷阱（见下文"复核-执行"标记）；
- 核对 pnpm 依赖布局、flutter_local_notifications 插件 manifest、Dockerfile 运行期依赖路径；
- 交叉比对前后端接口字段（例如 worker 输出 vs Web 客户端映射）。

### 1.3 限制（请知悉）

1. **移动端未能运行 Flutter 测试**：沙箱禁止 Dart 启动子进程（`Process.run`/`Process.start` → `拒绝访问`，`process_win.cc:744`），且 Flutter 工具需写 `C:\dev\flutter\bin\cache`（工作区外）。已尝试复制 SDK 进工作区绕过，仍受子进程限制。因此移动端结论为**代码级确认**（逐行 + 调用链 + 插件源码/官方 README 交叉核对 + SQL 语义用 SQLite 实际执行），**未在真机/模拟器运行**；运行期相关的 5 项已在 [9.4 移动端复核](#94-移动端复核2026-10-29-追加) 单独列出。
2. 未启动 Docker / Postgres / Redis / 真实 FCM / 真实 LLM；相关结论基于配置与代码路径，不使用容器验证。
3. `pnpm` 在本沙箱因 spawn EPERM 不可用，改用直接调用 `tsc` / `ts-node` 完成验证。
4. 严重度是本报告的判断（按"医疗数据安全 / 数据丢失 / 主流程不可用"排序），可能因部署方式不同而变化。

### 1.4 统计（去重后）

| 严重度 | 数量 | 含义 |
|---|---|---|
| **Critical** | **4** | 隐私泄露 / 静默数据丢失 / 解析链路被数据销毁 |
| **High** | **28** | 越权、错误医疗数据、核心功能不可用、部署必挂、备份不可用 |
| **Medium** | **63** | 边界条件错误结果、校验缺失、非原子写、竞态 |
| **Low** | **42** | 健壮性 / 体验 / 测试与文档问题 |
| 合计 | **137** | 6 份区域报告原始 140 条；合并 2 组重复项、复核上调 1 条严重度、移动端复核撤回 1 条 |

> 标注说明：**[复核-执行]** = Lead 亲自跑代码/工具复现；**[复核-代码]** = Lead 逐行核对过证据链；**[静态]** = 审阅者静态追踪确认，未独立复现。

---

## 二、总体判断：三类系统性问题

这不是"零星手误"，而是三条系统性裂痕：

**A. 备份 / 恢复链路不可信（最影响真实用户）**
本地 JSON 与云端密文都只导出 8 类表，恢复只回填 3 类；检查/手术/用药打卡/副作用从未进入备份；云端备份的 KDF salt 是"重装即变"的本地 UUID；明文库迁移还会永久残留一份明文数据库副本。也就是说：**备份看起来成功，换机时救不回来。**

**B. 服务端身份与授权边界不足**
`appUserId`（本地生成 UUID）本身就是云数据的唯一凭证；parse 端点有 IDOR；`/medications/timeline` 跨租户泄漏副作用事件；登出接口实际无效；文档宣称的 DPoP/PoP 防护在服务端从未真正校验（且验签实现必然失败）；社区 Skill 可被匿名改写成全局解析模板。

**C. 部署 / CI 与文档不一致，造成"看起来能跑"**
API 镜像漏拷 workspace 依赖（容器必挂）；根 `.env.example` 缺 compose 强制要求的变量（一键启动必挂）；compose 默认把短信验证码置空且打开开发登录（非生产部署=任意手机号无验证码登录）；env-guard 只黑名单两个字面量，项目自己的 `change-me-*` 占位符可一路带入生产。

---

## 三、Critical（4 条）

### C1. `GET /medications/timeline` 泄漏**所有患者**的副作用事件 — [复核-代码]

- **位置**：[medication.service.ts:186](services/api/src/modules/medication/medication.service.ts#L186)
- **证据**：副作用查询 `createQueryBuilder("ae").innerJoin(MedicationEntity, "m", "m.id = ae.medicationId")`，**没有任何 patient/user 过滤**（join 只为取药名）。
- **影响**：任意持 `full` scope token 的用户请求一次，即可拿到全库所有患者的 `adverseEvents`：标题（如"带状疱疹""反复感染"）、严重度、日期、`medicationId`、药名。`chainText` 是对的，所以冒烟测试完全看不出来。
- **修复**：`innerJoin(..., "m.id = ae.medicationId AND m.patientId = :pid")`，或先取出该 patient 的 medication id 列表再 `In(...)`。

### C2. SQLCipher 迁移永久残留一份**明文全库副本** — [复核-执行]

- **位置**：[local_db.dart:114-117](apps/mobile/lib/core/db/local_db.dart#L114-L117)
- **证据**：明文库迁移成功后 `await file.copy('$path.plain.bak')`，全仓库 grep 无任何删除/清理路径；迁移只跑一次，之后旧文件再也不会被触碰。
- **影响**：从明文旧版本升级的用户，全部 PHI（检验/症状/用药/注射）以明文长期留在 `Documents/ibders_local.db.plain.bak`，可被系统备份、越狱/root、取证镜像直接读取 —— 加密落盘的设计对这批用户完全失效。项目自述"医疗数据留在本机（加密）"，故定级 Critical。
- **修复**：加密库成功打开后删除 `.plain.bak`；失败时保留并记录待清理，下次启动重试；补一条"迁移后 .plain.bak 不存在"的回归测试。

### C3. Web 端**批量解析**：confirm 必然失败、异常被吞、云端 PDF 被删、行仍标记完成 — [复核-代码]

- **位置**：[ParseBatch.tsx:92-109](apps/web/src/pages/ParseBatch.tsx#L92-L109)；契约来源 [skill_engine.py:17-24](services/parse-worker/app/skill_engine.py#L17-L24)
- **证据**：worker 输出的 item 是 snake_case（`name` / `name_raw` / `ref_min` / `ref_max`），Web 直接 `as LabItemDto[]` 并读取 `i.nameNorm` / `i.refMin`（全是 `undefined`）→ confirm 提交的 items 缺 `nameNorm`；API 的 `lab_items.nameNorm` NOT NULL → 500；`catch { deleteParseSource(...) }` 吞掉错误，随后 `patch(status:"done")`。
- **影响**：Web 端主功能"批量解析"**一份都写不进去**，而且"用完即删"已经把用户上传的 PDF 原件删掉 —— 数据丢失且 UI 显示成功。App 端/ e2e 用的是另一套字段映射，所以 CI 绿。
- **修复**：服务端在 `markCompleted` 时统一归一化 worker 输出（snake→camel）并给 `ParseJobDto.items` 建真实类型；confirm 失败不得删源、不得标 done；补一条 Web 端 confirm 的 e2e。

### C4. 定性检验值（"阴性"）被转成 `NaN`，直接打挂解析链路 — [复核-代码 + 审阅者 venv 复现]

- **位置**：[ai_engine.py:76-84](services/parse-worker/app/ai_engine.py#L76-L84)
- **证据**：`float(re.sub(r"[^0-9.\-]", "", value) or "nan")` —— "阴性" 清空后回落为 `float("nan")`，仍被塞进 `ParsedItem`；Starlette 与 bullmq 序列化均 `allow_nan=False` → 抛错 → `/parse` 500 / 任务 failed。
- **影响**：LLM 兜底路径本应"解析失败就退回人工录入"，但只要报告里出现一个定性项（真实化验单非常常见），**整份报告**解析失败；Job 重试也必然重放。
- **修复**：`"nan"` 分支改为丢弃该 item（或保留原文到 `name_raw` 并 `value=None`）；Pydantic 模型加 `allow_inf_nan=False`；补"含定性值报告"的回归用例。

---

## 四、High（28 条，重点 12 条详见，其余见下表）

### H1. 备份/恢复静默丢数据：导出 8 类、恢复只回填 3 类；另有 4 类**从未**进入备份 — [复核-代码]

- **位置**：[backup_service.dart:55-71](apps/mobile/lib/core/backup/backup_service.dart#L55-L71) vs [:86-139](apps/mobile/lib/core/backup/backup_service.dart#L86-L139)；恢复入口 [settings_page.dart:342-376](apps/mobile/lib/features/settings/settings_page.dart#L342-L376)
- **证据**：`exportAll()` 写 8 个集合（labs / medications / injections / symptoms / bathroom / surveys / foodLogs / drugReviews）+ skill 计数；`importFromJsonString()` 只读 `labs` / `medications` / `injections`；`restoreFromCloud()` 返回的"已恢复 N 条"也只统计这 3 类。
- **影响**：打卡日记、排便细表、PHQ-9/IBDQ/SF-36 量表、饮食日志、药物评价在换机/重装后**全部消失**，UI 仍提示"导入完成 / 已从云端恢复 N 条"。另外 `exams`（肠镜/影像，含 SES-CD）、`surgeries`、`medication_checkins`、`adverse_events` 连导出都没有 —— 对 IBD 患者，内镜与手术史是最关键的临床记录，却从未被备份。
- **修复**：导出/导入共用一份 manifest（表 → 行映射），全部表进事务、逐表回报数量；清空或按主键 upsert 避免重复导入；加 `export→import→export` 深比较测试。

### H2. 换机/重装后，加密云备份**无法解密** — [复核-代码]

- **位置**：[backup_crypto.dart:12-22](apps/mobile/lib/core/backup/backup_crypto.dart#L12-L22)、[local_identity.dart:26-36](apps/mobile/lib/core/identity/local_identity.dart#L26-L36)
- **证据**：PBKDF2 salt = `utf8.encode(appUserId)`，而 `appUserId` 是首启生成、只存在本机 SharedPreferences 的 UUID；恢复流程 `syncSession(identity.uuid)` 用的是**当前**新 UUID，口令存在 Keystore/Keychain（卸载即失）。
- **影响**：README 宣称"换机用同一 appUserId + 口令恢复"，但 App 里既没有输入旧 appUserId 的入口，也没有导入口令的入口；实际效果是**云备份只能在同一台未卸载的设备上恢复**，"灾备"价值为零。
- **修复**：salt 改为备份文件内自带的随机 salt（与 appUserId 一起写入 header）；恢复时允许输入/导入 appUserId 与口令；或引入独立恢复码（12 词/BIP39 类）。

### H3. Android 缺少通知插件要求的 Receiver → **所有定时提醒静默不触发** — [复核-执行]

- **位置**：[AndroidManifest.xml:1-49](apps/mobile/android/app/src/main/AndroidManifest.xml#L1-L49)
- **证据**：manifest 只有 `INTERNET` / `POST_NOTIFICATIONS`，没有 `ScheduledNotificationReceiver`、`ScheduledNotificationBootReceiver`，也没有 `RECEIVE_BOOT_COMPLETED`；核对 pub cache 中 `flutter_local_notifications-17.2.4` 的插件 manifest，同样不含这两个 Receiver（需 App 自行声明）。
- **影响**：注射/服药/复查的**所有 zonedSchedule 定时通知在 Android 上都不会响**，而 App 内"发送测试通知"（即时通知）是好的 —— 用户以为提醒已开启。这是核心功能级缺陷。
- **修复**：按插件 README 在 `AndroidManifest.xml` 的 `<application>` 内声明两个 Receiver 与 `RECEIVE_BOOT_COMPLETED` 权限；补一次真机/模拟器验证。

### H4. 注射 Tab 从不加载已保存计划，"今天已打"入口不可达 — [复核-代码]

- **位置**：[injection_page.dart:33-41](apps/mobile/lib/features/injection/injection_page.dart#L33-L41)、[:154-162](apps/mobile/lib/features/injection/injection_page.dart#L154-L162)
- **证据**：`initState` 只初始化表单与预览，`_rows` 初始 `[]`；唯一写 `_rows` 的 `_loadRows()` 只被刷新按钮、下拉刷新和 `_complete` 调用；页面由 [shell_page.dart:44](apps/mobile/lib/features/shell_page.dart#L44) 的 `IndexedStack` 长期持有，State 不会重建。
- **影响**：冷启动后进入"注射"页永远显示"暂无数据，生成后在此列出"，无法对既有计划点"今天已打"；用户唯一能做的"重新生成"会调用 `clearPendingForDrug` 删掉同药未完成针次并重写排期。核心页基本不可用。
- **修复**：`initState` 中 `_loadRows()`（其内部已判断 `mounted`），并在 Tab 可见时重新加载。

### H5. Compose 默认值把短信验证码置空 → **任意手机号免验证码登录**（非生产部署） — [复核-执行]

- **位置**：[docker-compose.yml:57-58](docker-compose.yml#L57-L58)、[auth.service.ts:20](services/api/src/auth/auth.service.ts#L20)、[:85-91](services/api/src/auth/auth.service.ts#L85-L91)
- **证据**：compose 中 `DEV_SMS_CODE: ${DEV_SMS_CODE:-}` 会把变量**设为空串**（不是 unset）；`process.env.DEV_SMS_CODE ?? "123456"` 的 `??` 不会回落到默认值 → 期望验证码 = `""`；请求省略 `code` 时 `input.code ?? ""` 也是空串，`timingSafeEqual(空, 空)` 返回 true；同一文件 `ENABLE_DEV_SMS_LOGIN: ${ENABLE_DEV_SMS_LOGIN:-true}` 又默认打开了开发登录开关。
- **影响**：任何用仓库 compose 起在 `NODE_ENV=development` 的实例（staging/demo 常见且可能有真实账号），`POST /api/v1/auth/login {"phone":"<任意号码>"}` 即返回 `scope:"full"` token，可读写该号码患者全部 PHI；文档中写明的 `123456` 反而会 401。生产环境被 env-guard + 硬拒绝挡住（见 H12）。
- **修复**：空串视为未设置（`?.trim()` 后校验长度），显式拒绝空 code；compose 默认改 `ENABLE_DEV_SMS_LOGIN:-false`，并不要默认注入空 `DEV_SMS_CODE`。

### H6. `.env` 中的配置被静默忽略：模块级 `process.env` 早于 `ConfigModule.forRoot()` — [复核-代码]

- **位置**：[main.ts:4-8](services/api/src/main.ts#L4-L8)、[app.module.ts:24-28](services/api/src/app.module.ts#L24-L28)、[auth.service.ts:20-27](services/api/src/auth/auth.service.ts#L20-L27)、[data-source.ts:5-17](services/api/src/database/data-source.ts#L5-L17)
- **证据**：ESM 导入先于模块体执行；`main.ts` 导入 `app.module` 时，`auth.service`、`data-source` 的顶层常量已求值，而此时 `ConfigModule.forRoot()`（在装饰器参数里）尚未读取 `.env`。
- **影响**：按文档"复制 .env.example 后 `pnpm start:dev`"时，`DATABASE_URL(5433)` / `REDIS_URL(6380)` / `DEV_SMS_CODE` / `JWT_*_TTL` 全部不生效 → 连错库，或短信码配置/令牌时长悄悄失效；同一进程内不同组件对 `NODE_ENV` 的判断还可能不一致。
- **修复**：在 `main.ts` 第一行 `import "dotenv/config"`（data-source-cli 同理），或把这些常量改为 `ConfigService` 懒加载；`NODE_ENV` 单一来源。

### H7. `POST /auth/logout` 实际**不吊销** refresh token（TypeORM `null` 过滤陷阱）— [复核-执行]

- **位置**：[auth.service.ts:122-129](services/api/src/auth/auth.service.ts#L122-L129)
- **证据**：`refreshTokens.update({ tokenHash, revokedAt: null as never }, { revokedAt: new Date() })`。用 pg-mem + TypeORM 0.3.31 实测生成的 SQL 是 `UPDATE ... WHERE ("tokenHash" = $2 AND "revokedAt" = $3)`，`$3 = null` → 在 Postgres 中永远不匹配 → `affected = 0`，`revokedAt` 保持 NULL。
- **影响**："退出登录"后 refresh token 在 30 天内仍可换取新 access token；若设备令牌泄露/被复制，用户无法通过登出止损（结合 H8 的轮换竞态更糟）。
- **修复**：`update({ tokenHash, revokedAt: IsNull() }, ...)`，并检查 `affected === 1`；refresh 的轮换同理用 `IsNull()` + 事务。

> 同一类陷阱还出现在注射模块，见 H13。

### H8. `appUserId` 即能力凭证：任何人可为任意 UUID 领取同步/推送会话，并可**删除**他人云备份 — [静态，设计风险确认]

- **位置**：[auth.controller.ts:60-101](services/api/src/auth/auth.controller.ts#L60-L101)、[auth.service.ts:207-246](services/api/src/auth/auth.service.ts#L207-L246)、[sync.service.ts:71-75](services/api/src/modules/sync/sync.service.ts#L71-L75)
- **证据**：`POST /auth/sync-session {appUserId}` 无登录、无 PoP 强制（`REQUIRE_POP` 默认未开），直接为传入 UUID 建/取用户并签发 15 分钟 token；`DELETE /sync/ciphertexts` 仅按该 UUID 删除。
- **影响**：UUID 一旦泄露（日志、截图、共享、旧备份 JSON 中的 `appUserId` 字段、弱随机），攻击者可清空/覆盖受害者云端密文（服务端看不到明文，但**可用性攻击**成立），并绑定推送设备。项目文档承认"无登录墙"，但把"UUID 当密码"这一点写清楚并对删除/覆盖加二次确认/短期 PoP 是必要的。
- **修复**：短期方案——`DELETE /sync/ciphertexts` 要求 PoP 或二次确认 token；长期——恢复设备密钥对 + PoP（先修 H9 的验签实现）。

### H9. DPoP / PoP 防护"形同虚设"：验签实现必然失败，且服务端从不校验 X-PoP — [复核-执行]

- **位置**：[device-pop.ts:20-50](services/api/src/auth/device-pop.ts#L20-L50)、[auth.service.ts:217-226](services/api/src/auth/auth.service.ts#L217-L226)
- **证据**：(1) `isValidPublicKey` 要求 base64 解码后**恰好 32 字节**，随后却用 `createPublicKey({key: raw, format:"der", type:"spki"})` 解析 —— Node 实测 32 字节裸公钥作为 DER SPKI 会抛 `asn1 ... too long`，而真正的 Ed25519 SPKI DER 是 **44 字节**（会被前一判断拒绝）。因此任何合法 PoP 都验签失败；`REQUIRE_POP=true` 时**所有短会话签发都会 401**。(2) `requestSignPayload` / JWT 里的 `popKeyHash` 在全仓库**没有任何调用方**，即"token 被窃也无法单独使用"的承诺没有实现。
- **影响**：文档与实体注释宣称的防令牌盗用机制不存在；同时该模块让"开启 REQUIRE_POP"变成一个会让客户端全挂的开关。
- **修复**：公钥按 SPKI DER（或构造 `302a300506032b6570032100 + raw32`）解析，长度校验改为 32（裸）或 44（DER）并统一约定；实现请求级 X-PoP 守卫（nonce 存储 + 过期）；在 e2e 中覆盖 PoP 正/负用例。

### H10. Parse 端点越权（IDOR）：列表可读他人解析结果、入队可指定任意 patientId — [复核-代码]

- **位置**：[parse.service.ts:168-174](services/api/src/modules/parse/parse.service.ts#L168-L174)（list）、[:64-70](services/api/src/modules/parse/parse.service.ts#L64-L70)（enqueue）
- **证据**：其他模块统一用 `patients.resolveOwnedPatientId(userId, patientId)`（lab / medication / symptom / injection / reminder 都做了），**唯独 parse**：`list()` 直接 `const pid = patientId || ensurePatientForUser(...)` 后 `find({where:{patientId: pid}})`；`enqueue()` 直接 `input.patientId || ...`。匿名 `parse_session` 即可调用。
- **影响**：`GET /api/v1/parse/jobs?patientId=<他人×>` 返回他人解析任务（含 `items` / `confirmedItems` = 检验值 PHI）；`enqueue` 可把任务挂到他人档案，并用任意 `objectKey` 触发解析/删除源文件（`confirm` 的 `deleteSource` 会删 `job.objectKey`）。
- **修复**：两处都改用 `resolveOwnedPatientId`；`objectKey` 必须由 presign 时绑定当前 appUserId（服务端记录 owner），confirm/delete 校验归属。

### H11. 社区 Skill 可被**匿名改写为全局解析模板**（解析供应链风险） — [复核-代码]

- **位置**：[skill-community.controller.ts:23,78-89](services/api/src/modules/skill/skill-community.controller.ts#L78-L89)、[skill-community.service.ts:259-306](services/api/src/modules/skill/skill-community.service.ts#L259-L306)、[skill.service.ts:109-127](services/api/src/modules/skill/skill.service.ts#L109-L127)
- **证据**：`community-session` 是 `@Public()`，为任意 `appUserId` 签发 `community` scope；`POST /skill-community/skills/:id/collaborate` 接受该 token，脱敏白名单通过后**立刻** `skills.save({...skill, currentVersion: version})`，无审核/无人工批准/无限流；而 `parse.enqueue` 用 `getActiveSkillContent(hospital, reportType)` 取的就是这个 `currentVersion`，对所有患者生效。
- **影响**：攻击者（匿名）把某医院/某报告类型的正则改成"抓参考范围而不是结果值"，此后所有该院报告解析出错误检验值，用户确认后写入 `lab_results` 并被医生摘要引用 —— 影响面是全量用户，属于医疗数据完整性风险。
- **修复**：publish/collaborate 要求已认证贡献者（拒绝社区 scope 写路径）；新版本先入 `pending`，审核通过才提升 `currentVersion`；写路径限流；`confirm` 不得覆盖已审核社区模板。

### H12. 医生授权码接口**必然 500**，医生端授权流程不可用 — [复核-代码]

- **位置**：[doctor.service.ts:156-165](services/api/src/modules/doctor/doctor.service.ts#L156-L165)、迁移 [1727200000000:27](services/api/src/database/migrations/1727200000000-AddDoctorGrants.ts#L27)
- **证据**：`createCode` 写入 `patientId: ""`（注释"确认时绑定"），而 `doctor_grants.patientId` 是 `uuid NOT NULL` 无默认值 → Postgres 报 `invalid input syntax for type uuid: ""` → 500。api-modules 用 pg-mem 复现了 TypeORM 生成的 `INSERT ... VALUES (DEFAULT, '', ...)`。
- **影响**：医生无法生成授权码，`doctor-web` 的扫码授权链路整体不可用（M2 功能）。
- **修复**：把 `patientId` 改为 nullable（确认时再绑定）并同步实体/迁移；或生成时先占位 NULL + 加约束 `CHECK (confirmed = false OR patientId IS NOT NULL)`。

### H13. 注射排期：重复生成会**叠加重复计划**、完成接口重试会**重复顺延** — [复核-执行]

- **位置**：[injection.service.ts:76-86](services/api/src/modules/injection/injection.service.ts#L76-L86)（生成）、[:152-190](services/api/src/modules/injection/injection.service.ts#L152-L190)（完成）
- **证据**（实测 SQL）：
  - `count({patientId, drug, actualDate: null})` 中 `null` 被 TypeORM **丢弃** → `WHERE patientId=? AND drug=?`，把已完成的针次也算进去（`existing` 恒 >0）；
  - `delete({patientId, drug, actualDate: null})` 生成 `... AND "actualDate" = $3`，`$3=null` 在 Postgres 永不匹配 → **删除 0 行（静默 no-op）**；
  - 结果：每次"重新生成排期"都会在旧计划之上**再插入一整套**，`upcoming`/时间线/提醒出现重复针次。（api-modules 报告中的"data loss"表述据此更正为"重复"；"先删后校验、坏日期会 500"的风险仍存在。）
  - `complete()` 不检查 `job.actualDate` 是否已存在：重复调用会再次按同样的 `delayDays` 顺延后续所有未完成针次（+2 天 → 再 +2 天），且无事务。
- **影响**：注射计划与提醒被悄悄改乱，属于医疗安全级错误数据。
- **修复**：所有 `null` 条件改 `IsNull()`；生成前先校验日期、构建 rows，再在**同一事务**里 delete+insert（或用 `actualDate IS NULL` 的正确条件）；`complete` 加 `if (job.actualDate) return 409` 并用条件更新/事务包裹顺延。

### H14. 一键启动链路不可用：Docker 镜像缺运行期依赖 + `.env.example` 缺必填变量 — [复核-执行]

- **位置**：[Dockerfile:13-15](services/api/Dockerfile#L13-L15)、[docker-compose.yml:54,56](docker-compose.yml#L54-L56)、[`.env.example`](.env.example)
- **证据**：pnpm workspace 下 `@nestjs/*`、`typeorm`、`pg`、`ioredis`、`bullmq` 位于 `services/api/node_modules`（本机实测确认），Dockerfile 只 `COPY /app/node_modules`（根级只有 `.pnpm`/`.bin`/eslint 等），`node dist/main.js` 解析不到依赖 → 容器启动即 `MODULE_NOT_FOUND`；compose 用 `${NODE_ENV:?}`、`${JWT_SECRET:?}` 强制要求，而根 `.env.example` 只有 POSTGRES_*/MINIO_*/S3_*/STORAGE_*/PUBLIC_BASE_URL/LLM_*，**没有 NODE_ENV / JWT_SECRET / REDIS_PASSWORD** → `make dev` / `dev.ps1 -Docker` 在插值阶段就报错。
- **影响**：README/checklist 宣称的"一键启动"路径实际不可用；没有任何 workflow 构建镜像，所以 CI 永远发现不了。
- **修复**：构建阶段用 `pnpm --filter @ibd/api deploy --prod /out` 后整体 COPY（或 `node-linker=hoisted` + 拷 `services/api/node_modules` 与 `.pnpm`）；根 `.env.example` 补齐 compose 必填项；加一个"build image → 起容器 → 打 /health"的 CI job。

### H15. env-guard 生产"默认密钥"检查只看 2 个字面量，项目自带占位符全部放行 — [复核-代码]

- **位置**：[env-guard.ts:44-55](services/api/src/config/env-guard.ts#L44-L55)、[services/api/.env.example:11,27](services/api/.env.example#L11)
- **证据**：只拒绝 `"dev-storage-secret"` 与 `"dev-jwt-secret-change-me"`；而项目示例值是 `change-me-jwt-secret` / `change-me-storage-secret`，长度也足够 → 生产环境可带着**公开已知**的 JWT 签名密钥/上传签名密钥启动。
- **影响**：README"生产拒绝默认密钥"的承诺不成立；可被伪造 JWT（尤其配合 `full` scope）与伪造上传签名。另有 `DOCTOR_ADMIN_TOKEN` 为生产强制项，却未出现在任何 `.env.example`/compose/配置文档中 → 按文档部署会 crash-loop。
- **修复**：拒绝 `/^(change-me|dev-|test-|example)/i` 与已知示例值，强制最小长度/熵；补负向 smoke（用 `.env.example` 原值断言必须失败）；把 `DOCTOR_ADMIN_TOKEN` 写进所有示例与配置文档。

### H16. 登录会话被"短会话 401"误清 + 刷新令牌轮换竞态 — [静态]

- **位置**：[auth_session.dart:13-21,65-107](apps/mobile/lib/core/auth/auth_session.dart#L13-L21)、[ibd_api_client.dart:125-127](apps/mobile/lib/core/api/ibd_api_client.dart#L125-L127)、[my_doctors_page.dart:93-97](apps/mobile/lib/features/analysis/my_doctors_page.dart#L93-L97)
- **证据**：`AuthSession.parseSession()` 用**新的 `TokenStore()`** 构造一个仅含解析 token 的会话；请求 401 时 `_send` 调 `session.tryRefresh()` → 用空 refreshToken 换 token 必 401 → `logout()` → `_store.clear()` 删除**真实登录**的 access/refresh token。另 `tryRefresh` 无 single-flight，多个页面并发 401 会对同一个正在轮换的 refresh token 连续刷新，后到者失败 → 静默登出。
- **影响**：解析/医生页偶发 401 会把用户其它登录态一并清掉；并发请求下随机被登出。
- **修复**：解析会话使用独立的 `TokenStore`（内存态）或标记 `ephemeral`，禁止其 `logout` 触碰持久化存储；`tryRefresh` 用一个共享 `Future` 做 single-flight，并在刷新失败时区分"本会话"与"全局会话"。

### H17. 检验趋势用子串匹配：`白蛋白` 系列混入 `前白蛋白`（单位不同） — [复核-代码]

- **位置**：[repositories.dart:476-489](apps/mobile/lib/core/db/repositories.dart#L476-L489)、面板定义 [lab_panels.dart:79,330](apps/mobile/lib/core/lab/lab_panels.dart#L330)
- **证据**：`seriesByName` 使用 `WHERE lab_items.name_norm LIKE '%<name>%'`；`kCoreLabNames` 同时含 `白蛋白`(g/L) 与 `前白蛋白`(mg/L)，`'%白蛋白%'` 会同时命中两者，再按日期取 `last`。
- **影响**：趋势图/最近核心指标/医生访视摘要可能把 前白蛋白 的值画进 白蛋白 序列（数值量级差 1000 倍），产生错误医疗展示。
- **修复**：精确匹配 `name_norm = ?`（必要时别名表），或对核心指标用白名单精确名；补一条"两指标同时存在"的单测。

### H18. 解析兜底的其它崩溃路径（一条坏数据废掉整份结果 / 超时与非 JSON 未捕获 / 可选组 `float(None)`） — [静态 + 审阅者 venv 复现]

- **位置**：[ai_engine.py:85-95,116-118](services/parse-worker/app/ai_engine.py#L85-L95)、[llm_port.py:73-80,99-102](services/parse-worker/app/llm_port.py#L73-L80)、[skill_engine.py:106-114](services/parse-worker/app/skill_engine.py#L106-L114)
- **证据**：任一 item 的 `ref_min/ref_max/date` 非法 → Pydantic `ValidationError` → `ai_parse` 返回空 items（整份放弃）；`complete_json` 的读取超时/非 JSON 响应不在 `except (RuntimeError, ValidationError)` 覆盖范围 → 冒泡 500；skill 规则若捕获组可选/多选，`float(m.group(1))` 收到 `None` → `TypeError` 打断整份解析且 AI 兜底被跳过。
- **影响**：真实报告里常见"参考范围写 `"` / `—` / 跨行"，会随机导致解析失败或整份丢结果。
- **修复**：逐项容错（坏的 ref 置 None、坏的 item 跳过计 warning）；`complete_json` 包成只抛 `RuntimeError` 的统一错误类型；`group(1)` 为 None 时回退 `group(0)` 或跳过该规则。

---

### 其余 High（1 行版，详见区域报告）

| # | 问题 | 位置 | 影响 | 修复 |
|---|---|---|---|---|
| H19 | 备份导出遗漏 4 类表（检查/手术/用药打卡/副作用） | `backup_service.dart:57-70`、`data_exporter.dart:193-203` | 内镜/手术/依从性记录永远无法备份 | 纳入 H1 的 manifest |
| H20 | parse `confirm` 非幂等 | `parse.service.ts:179-248` | 双击/重试生成重复检验单 + 重复 Skill 版本 | `confirmedAt` 已存在返回 409；事务 + `FOR UPDATE` |
| H21 | `switch`/`adjust` 非原子 | `medication.service.ts:117-181` | 停旧成功、开新失败 → 患者"被停药"无替代 | `manager.transaction` 包裹 + 先校验 |
| H22 | parse `enqueue` 接受任意 `objectKey` | `parse.service.ts:64-70` | 可解析/删除他人上传文件 | presign 时绑定 owner 并校验 |
| H23 | 小程序检验页永远 401（从不取 token 却调受保护接口） | `apps/miniapp/src/lib/api.ts:31-55` | 小程序"检验查看"不可用 | 走 `parse_session`/`sync_session` 或改匿名只读接口 |
| H24 | Web 无法读取 App 导出的 JSON（`name_norm` vs `nameNorm`） | `apps/web/src/pages/Trends.tsx:52-56`、`DataExport.tsx:37-45` | Web 数据分析/导出对 App 备份全空 | 服务端/客户端统一字段归一化 |
| H25 | `env-guard` 未覆盖 `DOCTOR_ADMIN_TOKEN` 文档化 | `env-guard.ts:36-41` | 按文档部署生产会 crash-loop | 写入 `.env.example`/compose/config 文档 |
| H26 | 注入 `actualDate IS NULL` 条件在 ORM 中失效（关联 H13 的完成/顺延逻辑） | `injection.service.ts:170-186` | 已完成记录被纳入"未来计划"参与顺延 | 全部改 `IsNull()` |
| H27 | 工具链/版本漂移（Docker Node22 vs CI Node20、Flutter `stable` 未锁定、minio `latest`） | `services/api/Dockerfile:1`、`.github/workflows/*` | 构建不可复现、升级即红 | 固定版本/摘要 |
| H28 | 通知调度代码正确但**未在 manifest/权限上闭环**（同 H3 的另一半：`RECEIVE_BOOT_COMPLETED` 缺失导致重启后丢失） | 同 H3 | 重启后提醒丢失 | 同 H3 |

> 说明：H28 与 H3 同源，保留是因为"开机后丢失"与"从不触发"是两种不同故障现象；修复一并完成即可。

---

## 五、Medium（63 条，按主题聚类）

完整清单见各区域报告，这里给出**最可能被用户感知**的一批：

### 5.1 数据正确性（医疗）
| 问题 | 位置 | 影响 |
|---|---|---|
| 年度报告用 `m['endDate']`，而行是 snake_case → 停药判定永不生效 | [annual_report.dart:52-58](apps/mobile/lib/core/report/annual_report.dart#L52-L58) | 早已停用的药被算进之后每一年"用药变更" |
| `symptom.upsert` 缺 `date` 时 ORM 丢弃条件，覆盖**任意一天**日记 | `symptom.service.ts:30-52` | 随机改写历史症状记录 |
| `symptom.upsert` 丢弃 `bowelCount/urgency/mucus` | `symptom.service.ts:36-45` | 医生摘要显示"无紧迫/无黏液"（假阴性） |
| 手动排便"便血"布尔存成 flag=1，回显为更轻的"擦拭有血" | `clinical_pages.dart:217-240`、`repositories.dart:359-382` | 症状严重度被低估 |
| 提醒"今天"按 UTC 日历日计算 | `reminder.service.ts`（due） | 东八区 0–8 点判错日 |
| 医生"近 7 日"告警取最近 7 条记录而非 7 个日历日 | `doctor-data.module.ts:145-159` | 长期不打卡者告警失真 |
| 检验参考区间只按男性、且缺少按性别/年龄选择 | `lab_panels.dart` | 女性/儿童指标误标 high/low |

### 5.2 状态与交互（移动端）
| 问题 | 位置 | 影响 |
|---|---|---|
| 编辑用药：旧行 reason 被"编辑"覆盖 + 伪造当日停药 + 重复行 | `medication_edit_page.dart:212-224` | 用药史不可信 |
| 编辑用药：自定义服药时间被重置为 08:00 默认 | `medication_edit_page.dart:48-88,172-179` | 服药时间悄悄改变 |
| 药评自动补全每次 rebuild 清空手输药名 | `drug_review_page.dart:186-203` | 无法保存评价 |
| 打卡页跨日不重绑 → 昨天的值/已保存状态写进今天 | `symptom_page.dart:88,230` | 记错日期 |
| 首页跨 Tab 状态不刷新（打卡/注射后仍显示未完成） | `dashboard_tab.dart` | 误导 |
| 保存按钮无 in-flight 保护 → 重复行 | 量表/药评/饮食页 | 重复记录 |
| 解析超时后源文件不删（与"用完即删"文案不符） | `lab_entry_page.dart:378-389` | 云端残留 PHI |
| 检验日期自由文本未校验 → 记录从年度报告消失 | `lab_entry_page.dart:491` | 数据不可见 |

### 5.3 服务端健壮性 / 校验
| 问题 | 位置 | 影响 |
|---|---|---|
| 无全局 `ValidationPipe`、无 `class-validator`；接口 DTO 是 interface（运行时无校验） | `main.ts`、`package.json` | 大量 500 与 mass-assignment 的根因 |
| `PATCH /medications/:id` 可 mass-assign `patientId` / 任意状态 | `medication.service.ts:107-114` | 跨租户写入（需知 UUID） |
| `injection.create` / `reminder.create` 透传 body（含客户端 `id`） | `injection.service.ts:57-63` | 覆盖/伪造主键 |
| 上传入口无大小上限（20MB 检查只在 worker 后置） | `files.controller.ts:41-76` | 内存/磁盘 DoS |
| `upcoming?withinDays=abc` → `RangeError` 500 | `injection.service.ts:38-55` | 可用性 |
| `sync.putCipher` 版本比较静默丢弃上传且非事务 | `sync.service.ts:25-62` | 客户端以为已同步 |
| `ensurePatientForUser` 无唯一索引，可并发出双档案 | `patient.service.ts:21-34` | 数据分裂 |
| 限流 key 含攻击者可控 `appUserId` → 可绕过且每次建 users 行 | `auth.controller.ts:110-119` | 刷库/绕过限流 |

### 5.4 解析服务 / 前端
| 问题 | 位置 | 影响 |
|---|---|---|
| skill `crp_multiline` 用整份报告第一个数字覆盖值（常是年份/日期） | `rules.py:35-46` | CRP 被解析成 2026 |
| 社区 Skill 用 `refRange`，worker 只读 `ref_range` | `skill-community.scrub.ts` vs `skill_engine.py:115-123` | 参考区间/flag 全丢 |
| 同一份报告重复解析会重复生成检验项 | `lab_entry_page.dart` parse review | 重复指标 |
| 本地 Skill 兜底 `glob` 全量 JSON 无错误隔离，单个坏文件炸所有查询 | `skill_engine.load_skill:55-61` | 解析整体不可用 |
| 上传接受 PNG/JPG/TXT，worker 只解析 PDF | `apps/web` + `pdf.py` | 用户拿到空结果 |
| 预签名上传 URL 是跨域，而 API 默认 CORS 为空 → 文档开发流程浏览器上传被拦 | `main.ts:14-18`、`files.controller` | Web 批量上传不可用 |
| `boto3` 未声明但文档宣称支持 S3/MinIO | `requirements.in` / `main.py:121-136` | S3 部署每个任务失败 |
| worker 日志打印 LLM 输出/网关错误体（PHI） | `ai_engine.py:117`、`llm_port.py:76-78` | PHI 落日志 |
| 扫描件 3× 栅格化所有低文本页，但只发 4 张 | `pdf.py:20-28` | 内存/CPU 浪费 |

### 5.5 基础设施 / CI
| 问题 | 位置 | 影响 |
|---|---|---|
| Fullstack E2E 只在 push main 跑，PR 不跑 | `.github/workflows/ci-fullstack.yml` | PR 回归直接进主干 |
| E2E 的"Skill 命中"断言从不检查 `engine`，AI 兜底也能过 | `e2e-fullstack.mjs` | 假绿 |
| `migration-smoke` 只跑 2/15 个迁移 | `services/api/scripts/migration-smoke.ts` | 迁移回归漏检 |
| 文档写 5433/6380，compose 实际 5432/6379 | `docs/configuration.md` vs compose | 连不上库 |
| `RUN_MIGRATIONS` compose 默认 true，与加固清单矛盾 | `docker-compose.yml` | 生产自动改库 |
| 无 `.dockerignore`，构建上下文含宿主 node_modules（GB 级） | 根目录 | 构建慢/串入脏文件 |
| Makefile Windows 分支路径多了一层 `services/parse-worker/` | `Makefile` | Windows 上 worker 起不来 |
| `PARSE_QUEUE` 文档可配，代码硬编码 `parse` | `parse.constants.ts` | 改配置即断 |

> Medium 清单完整版：api-core 7 条、api-modules 10 条、mobile-core 8 条、mobile-features 12 条、worker-web 15 条、infra 12 条（含上表全部条目）。

---

## 六、Low（42 条）

不逐条展开，主要类别：

- **健壮性**：`ScopeGuard` 缺 user 时 fail-open（默认 `"full"`）；`SkillController` 无 scope；`setState` after await 缺 `mounted`；controller 未 dispose；`!_` 强制解包。
- **测试质量**：`shell_tabs_test` 自证式断言；widget 测试用 camelCase fixture（生产不会出现）；迁移测试复制 SQL 而非调用生产 `_onUpgrade`；隐私 smoke 未接入 CI。
- **文档/一致性**：README 宣称的 fuzz/300ms 等不存在；`docs/security-checklist.md` 对 IDOR/20MB 上限过度承诺；导出页声称 4 个文件实际 5 个；语言选择器无效果；根 `index.html` 带"AI生成"水印。
- **体验**：注射 `week_number` 写成序号导致时间线周次错；药评上传是死代码；`ScrollController` 在 `build` 里 new；CSV 公式注入（`=cmd`）；CSV 未转义 `\r`；明文 JSON 备份文件留在 Documents 且不清理。

---

## 七、已验证正确的关键点（避免误伤，也说明"不是全盘否定"）

审阅中明确验证为**正确/良好**的部分：

**安全与隐私（API）**
- CORS 显式白名单（不再反射任意 Origin）、生产关闭 Swagger、`env-guard` 在 `main.ts` 启动前执行（其自身条件有效）；
- 本地存储 `resolveSafe` 正确拒绝路径穿越/绝对路径/NUL；HMAC 预签名用 `timingSafeEqual`；
- 同步接口只存 `cipher/nonce/mac`，服务端无解密路径；push payload 为通用文案（无药名/剂量/PHI），FCM 未配置时 dry-run；
- lab/medication/symptom/injection/reminder/patient 的 patientId 归属校验一致且正确（parse 除外，见 H10）；
- scope 守卫在各控制器上应用一致（`sync/parse/files/push/doctor/skill-community` 均限定 scope）。

**移动端加密与数据流**
- AES-GCM 每次随机 nonce，MAC 随 `SecretBox` 校验；PBKDF2-HMAC-SHA256；DB key 32 字节 CSPRNG 存 Keystore/Keychain；旧明文 token/口令的迁移后删除；
- 解析上传**必须**先点"同意上传并解析"，结果只回填表单不自动落库；解析会话 30 分钟；
- 打卡↔排便细表的双写有唯一约束 + 按 date 幂等；CSV 转义正确；PHQ-9 分段、SF-36 8 维度映射、Bristol/疼痛取值范围正确。

**解析服务 / 前端**
- Skill 正则 ReDoS 防护（嵌套量词/量词数/长度限制）；上传临时文件清理；PDF 页数/图片数上限；医生数据按 grant scope 过滤并写审计日志；web/doctor-web 的 token 存储与过期处理路径基本正确。

**工程基线**
- `pnpm-lock.yaml` 与 workspace 同步；未发现提交真实密钥；所有 TS 类型检查 0 错误；10 个冒烟脚本断言真实（非恒真）。

---

## 八、建议修复顺序

**P0（数据安全 / 当场止损，建议本周）**
1. H5 空短信码后门（若已部署非生产实例）+ H15 env-guard 占位符（生产密钥）；
2. C1 `/medications/timeline` 跨租户泄漏；
3. C2 明文 `.plain.bak` 残留（升级用户立即删除）；
4. C3 Web 批量解析删原件 + C4 NaN 打挂解析；
5. H7 登出无效（`IsNull()`）。

**P1（核心可用性 / 数据可靠性）**
6. H1+H2 备份/恢复重构（导出导入同源、salt 随包、换机入口）；
7. H3 Android 通知 Receiver；
8. H4 注射 Tab 加载；
9. H10 parse IDOR + H8 appUserId 凭证强化 + H9 PoP；
10. H11 社区 Skill 审核闸门；
11. H12 医生授权码；
12. H13 注射 `IsNull()`/事务、H21 用药切换事务；
13. H14 Docker/.env 一键启动；
14. H16 会话清理与刷新竞态。

**P2（Medium / Low）**
按第五、六节逐模块清理；优先把**校验层**（全局 `ValidationPipe` + DTO class）和**备份表清单**做成单一事实源，可一次性消掉大量 Medium。

**同时建议补的测试（否则同类问题还会复发）**
- 契约测试：worker 输出 → API 归一化 → Web/App 渲染（当前 Web 与 App 各写一套映射）；
- 备份 `export→import→export` 深比较；
- 迁移后 `.plain.bak` 不存在；Android 通知 scheduled 的真机/仪器测试；
- 生产配置负向测试（`.env.example` 原值必须被 env-guard 拒绝）；
- CI 增加 docker build + 起容器打 `/health`；PR 跑 fullstack e2e。

---

## 九、附录

### 9.1 区域报告（含逐条证据、复现步骤、修复建议、覆盖清单）

- [var/review/api-core.md](var/review/api-core.md) — 16 条（0C/3H/7M/6L）
- [var/review/api-modules.md](var/review/api-modules.md) — 27 条（1C/7H/10M/9L）
- [var/review/mobile-core.md](var/review/mobile-core.md) — 24 条（1C/7H/8M/8L）
- [var/review/mobile-features.md](var/review/mobile-features.md) — 21 条（0C/2H/12M/7L）
- [var/review/worker-web.md](var/review/worker-web.md) — 31 条（2C/5H/15M/9L）
- [var/review/infra.md](var/review/infra.md) — 21 条（0C/5H/12M/4L）

> `var/` 被 `.gitignore` 忽略，属审阅工作产物；若需要入库，建议只保留本汇总报告，分报告按需归档。

### 9.2 复现/验证记录（Lead 执行）

| 验证 | 命令/方式 | 结果 |
|---|---|---|
| TS 类型检查 | `node .pnpm/typescript/bin/tsc -p <pkg> --noEmit` ×4 | 0 错误 |
| API 冒烟 | `ts-node --transpile-only scripts/*-smoke.ts` ×10 | 全 PASS |
| parse-worker 单测 | `.venv/Scripts/python -m app.tests.test_ai_engine` 等 | ALL_PASS / OK |
| TypeORM `null` 过滤语义 | pg-mem + TypeORM 0.3.31：`count/update/delete` | `find/count` 丢弃条件；`delete/update` 生成 `= NULL` 恒不匹配 |
| Ed25519 公钥解析 | Node `createPublicKey({format:"der",type:"spki"})` | 32 字节裸 key → `asn1 too long`；真实 SPKI DER = 44 字节 |
| Docker 依赖布局 | 检查根 `node_modules` 与 `services/api/node_modules` | 根无 `@nestjs/*`，故镜像必挂 |
| Android 通知插件 | 核对 pub cache 插件 manifest + 应用 manifest | 两处均无 Scheduled/Boot Receiver |

### 9.3 未做的事（明确边界）

- 未修改任何源码、未提交 commit、未改 `docs/session-worklist.md`；
- 未运行 Flutter 测试/真机、未起 Docker/DB、未调真实 LLM/FCM；
- 未做渗透测试与性能压测（本次是代码审阅，不是安全评估）。

### 9.4 移动端复核（2026-10-29 追加）

针对"未真机运行，静态结论可能失真"的担忧，对 45 条移动端结论做了第二轮复核（完整记录：[var/review/mobile-reverify.md](var/review/mobile-reverify.md)）。

**复核结果**

| 结果 | 数量 | 说明 |
|---|---|---|
| 确认 | 43 | 均有明确代码位置或可执行证据 |
| 确认但修正表述 | 1 | F-MOB-CORE-2：导出集合是 8 个（非 9），丢 5/8 |
| 撤回 | 1 | F-MOB-FEAT-8（取消/重选套餐重复项）未找到成立路径 |
| 影响收窄 | 1 | F-MOB-CORE-20：`latestLabItem` 两种命名都兼容，仅测试保真度问题 |

**Critical/High 的复核证据（摘要）**

- 明文 `.plain.bak`：迁移函数内 `file.copy(bak)` 后无任何删除路径，且每次启动 `_open()` 都会调用该迁移；
- 恢复丢表：14 张表中 `exams`/`surgeries`/`medication_checkins`/`adverse_events` 从未进入 `exportAll()`；导入只处理 3 类；
- 换机不可解密：salt = `appUserId`，而 `appUserId` 存 SharedPreferences 且首启随机生成；设置页无输入旧 ID 的入口；
- Android 提醒：应用 manifest、插件 manifest、插件官方 README 三方一致——Receiver 必须由 App 声明，当前缺失；
- 解析 401 清登录：`parseSession` 用空 refreshToken + 新 `TokenStore()`，`logout()` 清的是 static 存储里的真实令牌（调用链已完整追踪）；
- 刷新竞态：服务端 `refresh()` 先吊销旧 token 再签发，客户端 `tryRefresh` 无 single-flight；
- 白蛋白串味：SQLite 实测 `LIKE '%白蛋白%'` 命中 `['白蛋白','前白蛋白']`（量级差 1000 倍）。

**环境限制（为什么没有 `flutter test` 结果）**

- 沙箱禁止 Dart 启动子进程：自写脚本验证 `Process.run`/`Process.start` 均 `拒绝访问`（`process_win.cc:744`）；
- Flutter 工具需写 `C:\dev\flutter\bin\cache`（工作区外）→ `lockfile` 打不开；复制 SDK（0.91 GB）进工作区后仍因"子进程"失败；
- 结论因此分为"代码级确认（43 条）"与"待运行时确认（5 项）"。

**建议在真机回归时优先确认的 5 项**

1. Android 上 `zonedSchedule` 是否静默不触发（预期：不触发且不报错）；
2. 冷启动进入注射 Tab 是否显示"暂无数据"（预期：是，直到下拉刷新）；
3. 跨 Tab / 跨午夜后首页与打卡页状态是否陈旧（预期：是）；
4. 仅触碰睡眠控件后保存，`stress_level` 是否被写成默认值 5（预期：是）；
5. 存在逾期注射时重排提醒是否集中弹出（预期：`now+1min` 触发一批）。

---

*报告生成：6 个并行审阅代理 + Lead 交叉复核（移动端已二次复核）。若需要，我可以按 P0→P2 直接修复并补测试，或先把本报告条目按项目规范写入 `docs/session-worklist.md`。*
