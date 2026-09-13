# Flutter App（MVP）

按架构定稿：Flutter 3.x + 离线优先（Drift 后续接入）。

## 当前能力

- **直传解析**：`lib/features/parse/parse_upload_page.dart`
  1. `POST /api/v1/files/presign`
  2. 对 `uploadUrl` PUT 文件字节
  3. `POST /api/v1/parse/jobs`
  4. 轮询 job 至 `done` / `failed`，展示 items
- API 客户端：`lib/core/api/ibd_api_client.dart`
- 上传服务：`lib/core/storage/direct_upload_service.dart`

## 运行

需本机安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)，然后：

```bash
cd apps/mobile
flutter create --org com.ibd --project-name ibd_mobile .
# 保留已有 lib/ 与 pubspec（冲突时以仓库 pubspec 为准）
flutter pub get
# Android 模拟器默认 API http://10.0.2.2:3000
# 真机请覆盖：
flutter run --dart-define=IBD_API_BASE=http://192.168.x.x:3000
```

后端需已启动：Postgres migrations + Redis + `services/api`（见根 README）。

## 环境变量

| 变量 | 说明 | 默认 |
|------|------|------|
| `IBD_API_BASE` | API 基址 | `http://10.0.2.2:3000` |
