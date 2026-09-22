# 系统推送隐私边界（IBDers）

**原则：本地优先；远程推送 opt-in；推送不是登录门禁。**

---

## 1. 默认路径：本地通知

| 项 | 行为 |
|----|------|
| 注射提醒 | `flutter_local_notifications` 本机调度（提前 3 天） |
| 关网 | 全部可用，不依赖 FCM / 厂商通道 |
| 内容 | 本地通知可含药品与剂量（仅展示在本机通知栏，不上云） |

远程推送**关闭时**：零设备注册、零远程发送。

---

## 2. 远程推送（opt-in）

开启入口：`我的 → 系统推送`。开启后仅做两件事：

1. 获取设备推送令牌（FCM token；未接 SDK 时为本地占位串）
2. 调用 `POST /api/v1/auth/push-session` + `POST /api/v1/push/devices` 注册

### 2.1 令牌绑定

| 项 | 约束 |
|----|------|
| 绑定键 | **仅** `app_user_uuid`（`appUserId`） |
| 登录 | **不强制**；不依赖手机号 / 微信 |
| 存储 | 服务端 `device_tokens` 表：`appUserId` + `token` + `platform` |
| 注销 | 设置页「注销设备令牌」或关闭开关；`DELETE /api/v1/push/devices` 即时删除 |
| 门禁 | **禁止**把推送开关做成登录墙或功能门禁 |

### 2.2 Payload 白名单（硬约束）

远程推送 **title / body 只允许**下列通用文案：

| kind | title | body |
|------|-------|------|
| `medication` | IBDers | 您有一条用药提醒 |
| `injection` | IBDers | 您有一条注射提醒 |
| `followup` | IBDers | 您有一条复查提醒 |
| `system` | IBDers | 您有一条系统通知 |

`data` 仅可携带 `kind` 路由字段。

**禁止出现在推送中的字段**：药品名、剂量、给药途径、检验值、症状、诊断、手术、医院、报告原文、任何可识别病历内容。

客户端落地（`LocalNotifyService.showRemoteAsLocal`）对 title/body 做**白名单过滤**：非白名单字符串一律丢弃并降级为通用文案，防止上游误塞敏感信息。

---

## 3. 服务端发送策略（FCM_*）

| 配置 | 行为 |
|------|------|
| 未配置任何 `FCM_*` | **dry-run**：只记日志，不访问 Google |
| `FCM_SERVER_KEY` | 传统 FCM API 真实发送 |
| `FCM_PROJECT_ID` + `FCM_CLIENT_EMAIL` + `FCM_PRIVATE_KEY` | FCM HTTP v1 真实发送 |

无论是否真实发送，**payload 构造函数只输出通用文案**（见 `services/api/src/modules/push/fcm.service.ts` 的 `GENERIC_PUSH_COPY`）。

---

## 4. API 摘要

| 接口 | 说明 |
|------|------|
| `POST /api/v1/auth/push-session` | 短时会话（scope=`push_register`），入参仅 `appUserId` |
| `POST /api/v1/push/devices` | 注册/更新令牌 |
| `DELETE /api/v1/push/devices` | 注销单条（`token`）或全部（仅 `appUserId`） |
| `GET /api/v1/push/devices` | 查看条数与 token 前缀（不回显完整 token） |
| `POST /api/v1/push/notify` | 触发一条通用提醒（测试 / 定时任务入口） |

---

## 5. 用户可控项

- 关闭「系统推送」→ 本机 opt-in=false，并尝试删除服务端令牌  
- 「注销设备令牌」→ 确认后删除服务端绑定  
- 本地注射提醒与远程推送**解耦**：关推送不影响本地提醒  

---

## 6. 实现索引

| 层 | 路径 |
|----|------|
| 本地落地 + 白名单 | `apps/mobile/lib/core/notify/local_notify.dart` |
| 注册/注销客户端 | `apps/mobile/lib/core/push/push_service.dart` · `core/api/push_api.dart` |
| 设置页开关 | `apps/mobile/lib/features/settings/settings_page.dart` |
| device_tokens 表 | `services/api/src/database/entities/device-token.entity.ts` |
| 注册/注销 API | `services/api/src/modules/push/` |
| FCM dry-run / 真实发送 | `services/api/src/modules/push/fcm.service.ts` |
