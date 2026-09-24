# Firebase 凭据接入清单（解锁 T2）

目标：真机取到 **真实 FCM token**（非 `local:` 占位），服务端 `push:notify` 返回 `mode: fcm` 并真机收到通用文案。

> 密钥勿提交 git。`google-services.json` / `GoogleService-Info.plist` / `.env` 均已在 `.gitignore`。

---

## 1. 创建 Firebase 工程

1. [Firebase Console](https://console.firebase.google.com/) → 添加项目
2. 项目设置 → 记下 **项目 ID**（填 `FCM_PROJECT_ID`）
3. 添加应用：Android 包名必须是 **`com.ibd.ibd_mobile`**；iOS Bundle ID 与 `apps/mobile/ios` 一致
4. Cloud Messaging：启用 API（HTTP v1）

---

## 2. 客户端文件（App 取 token）

| 文件 | 来源 | 放到 |
|------|------|------|
| `google-services.json` | 项目设置 → Android 应用 → 下载 | `apps/mobile/android/app/google-services.json` |
| `GoogleService-Info.plist` | 项目设置 → iOS 应用 → 下载 | `apps/mobile/ios/Runner/GoogleService-Info.plist` |

无文件时 Gradle 跳过 google-services 插件（无密钥仍可构建）。

**可选** dart-define（不用 json/plist）：

```bash
flutter run \
  --dart-define=IBD_FIREBASE_PROJECT_ID=<projectId> \
  --dart-define=IBD_FIREBASE_APP_ID=<appId> \
  --dart-define=IBD_FIREBASE_API_KEY=<apiKey> \
  --dart-define=IBD_FIREBASE_SENDER_ID=<senderId>
```

---

## 3. 服务端 `FCM_*`（真发）

复制 `.env.example` → `.env`，二选一：

**A · 服务账号（推荐）** — 控制台生成私钥 JSON 后：

```env
FCM_PROJECT_ID=<project_id>
FCM_CLIENT_EMAIL=<client_email>
FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

**B · 传统密钥**：

```env
FCM_SERVER_KEY=<server key>
```

---

## 4. 验证

```bash
node services/api/scripts/fcm-config-smoke.mjs   # 检查 FCM_* 是否就绪
# App 设置·系统推送开启 → device_tokens 应为真实 token（非 local-）
# 点「系统通知测试」→ API {"dryRun": false, "mode": "fcm"} 且真机收到通知
```

| 检查项 | 通过标准 |
|--------|----------|
| T2.1 | `device_tokens.token` 为真实 FCM token（非 `local-`） |
| T2.2 | `push:notify` 返回 `mode: fcm` 且 `dryRun: false`，真机收到通知 |

---

## 5. 放好后

告知「文件已放入」或粘贴 `FCM_*`（会话可见）。我跑验证并更新 [session-worklist](session-worklist.md) T2.1/T2.2。真机联调见 T2.4 / T2.5。
