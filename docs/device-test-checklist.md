# IBDers 真机联调清单（P1+P2+P3）

## 0. 前置

| 项 | 要求 |
|----|------|
| 本机服务 | Postgres `5433` · Redis `6380` · API `3000` · parse-worker `8081` |
| Flutter SDK | 3.x，`flutter doctor` 通过（本机：`C:\dev\flutter`） |
| Android SDK | `C:\dev\android-sdk`（API 36 + build-tools 36 + platform-tools） |
| JDK | Microsoft OpenJDK 17（`JAVA_HOME`） |
| 网络 | 手机与电脑同一局域网；`IBD_API_BASE=http://<电脑IP>:3000` |
| Android | **模拟器 AVD `ibd_api34`（Android 14 / API 34）** 或真机；模拟器 API 用 `http://10.0.2.2:3000` |

```powershell
# 启动模拟器
C:\dev\android-sdk\emulator\emulator.exe -avd ibd_api34
# 查看设备
C:\dev\android-sdk\platform-tools\adb.exe devices
# 运行 App（模拟器）
cd apps/mobile
C:\dev\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=IBD_API_BASE=http://10.0.2.2:3000
```


```bash
# 后端
export DATABASE_URL=postgres://ibd:ibd@127.0.0.1:5433/ibd
export REDIS_URL=redis://127.0.0.1:6380
export STORAGE_DRIVER=local STORAGE_LOCAL_DIR=var/uploads
export PUBLIC_BASE_URL=http://<电脑IP>:3000
export RUN_MIGRATIONS=true
node services/api/dist/main.js
# worker
cd services/parse-worker && PORT=8081 python -m app.main

# App
cd apps/mobile
pwsh ./bootstrap.ps1
flutter run --dart-define=IBD_API_BASE=http://<电脑IP>:3000
```

## 1. 本地优先（P1）

| # | 步骤 | 期望 |
|---|------|------|
| 1 | 飞行模式冷启动 | 直接进首页，无登录 |
| 2 | 隐私页查看 UUID | 显示本机生成 UUID |
| 3 | 手动录入检验 2 项 | 保存成功，杀进程重开仍在 |
| 4 | 新增用药 + 停药 | 历史有切换记录 |
| 5 | 生成 Skyrizi 排期 | 列表出现；系统通知渠道已创建 |
| 6 | 症状打卡 | 保存到本机 |
| 7 | 抓包（Charles/Fiddler） | 飞行模式下无外发；未点解析无上传 |

## 2. 解析单次授权（P1/P2）

| # | 步骤 | 期望 |
|---|------|------|
| 8 | 选 PDF/txt，点取消 | stage=cancelled，无网络上传 |
| 9 | 同意上传 | 走 parse-session → presign → PUT → 解析 |
| 10 | 解析完成 | 结果写入本地 labs |

## 3. 可选云同步（P2/P3）

| # | 步骤 | 期望 |
|---|------|------|
| 11 | 开启同步，设口令 | syncOptIn=true |
| 12 | 上传加密快照 | 服务端 `sync_snapshots` 有 cipher/nonce/mac，无明文 |
| 13 | 另一台机/清数据 | 同 appUserId + 口令 →「从云端恢复」→ 数据回来 |
| 14 | 删除云端副本 | 表行删除，开关关闭 |
| 15 | 导出/导入 JSON | 换机可手动迁移 |

## 4. SQLCipher 全库加密（P3）

| # | 步骤 | 期望 |
|---|------|------|
| 16 | 设置页「本地库 SQLCipher」 | cipher_provider 非空；key=已生成 |
| 17 | adb pull / 文件导出 `ibders_local.db` | 非明文 SQLite（乱码或 header 非 `SQLite format 3`） |
| 18 | 从明文旧版升级 | 自动 ATTACH rekey；旧库备份为 `.plain.bak` |

## 5. 已知边界（本轮）

- 云端恢复需先上传过含 mac 的快照  
- iOS 需在 Xcode 里配本地通知权限描述  
- 密钥在 Keystore/Keychain，卸载重装会丢密钥（本地库不可读；需导出/云恢复）  

## 6. 签字

- [ ] 安卓真机  
- [ ] iOS 真机  
- [ ] 飞行模式全绿  
- [ ] 抓包确认默认零上传  
- [ ] SQLCipher 密文库验证  
