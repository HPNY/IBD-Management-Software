# Flutter App（MVP）

## 已实现

| 页面 | 路径 |
|------|------|
| 登录（手机号+验证码） | `lib/features/auth/login_page.dart` |
| 检验直传解析 | `lib/features/parse/parse_upload_page.dart` |
| 检验手动录入 | `lib/features/lab/lab_manual_page.dart` |
| 注射排期/提醒 | `lib/features/injection/injection_page.dart` |

- Token 持久化：`shared_preferences`（`TokenStore`）
- 会话：`AuthSession`（login / refresh / logout）
- API：`IbdApiClient` 自动 Bearer，401 自动 refresh 一次

## 首次工程化（需本机 Flutter SDK）

```bash
cd apps/mobile
# 在现有 lib/ 旁生成 android/ios 等平台工程
flutter create --org com.ibd --project-name ibd_mobile .
# 若 create 覆盖 pubspec，以仓库版本为准恢复 dependencies
flutter pub get
flutter run --dart-define=IBD_API_BASE=http://10.0.2.2:3000
```

或运行：

```powershell
pwsh ./bootstrap.ps1
```

后端：`DATABASE_URL` + `REDIS_URL` + API；登录验证码开发默认 `123456`。

## 环境变量

| 变量 | 默认 |
|------|------|
| `IBD_API_BASE` | `http://10.0.2.2:3000` |
