# IBDers Flutter App（本地优先）

## 原则

1. **本地权威**：病程写 `ibders_local.db`（sqflite），默认不上传  
2. **无登录墙**：首启生成 `app_user_uuid`；云能力仅可选「关联手机号」，永不强制登录  
3. **云端解析需单次同意**：弹窗确认后才上传该文件  

## 结构

| 路径 | 职责 |
|------|------|
| `lib/core/identity/local_identity.dart` | 应用 UUID + 同步开关 |
| `lib/core/db/local_db.dart` | SQLite schema |
| `lib/core/db/repositories.dart` | lab/med/injection/symptom 本地仓储 |
| `lib/core/injection/protocols.dart` | 本地生成注射排期 |
| `lib/core/notify/local_notify.dart` | 本地注射提醒 |
| `lib/features/*` | 本地页面（无登录门禁） |

## 运行

```bash
cd apps/mobile
pwsh ./bootstrap.ps1   # 需要 Flutter SDK
flutter run --dart-define=IBD_API_BASE=http://10.0.2.2:3000
```

断网可完成：手动检验、用药、注射排期、症状打卡。  
「上传解析」需显式同意；云同步走**可选关联手机号**（非登录门禁）。
