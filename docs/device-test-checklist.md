# IBDers 真机/模拟器联调清单（A 部分验收）

设备：**AVD `ibd_api34` · Android 14 · `emulator-5554`**  
后端：Postgres `:5433` · Redis `:6380` · API `:3000` · Worker `:8081`  
包名：`com.ibd.ibd_mobile` · 应用名：**IBDers**  
`IBD_API_BASE=http://10.0.2.2:3000`（模拟器访问宿主机）

---

## 结果摘要（2026-09-18）

| # | 项 | 结果 |
|---|-----|------|
| A1a | App 冷启动（无登录） | **通过** · pid 正常，进入底部导航壳 |
| A1b | 飞行模式启动 App | **通过** · wifi off 后仍可启动 pid 6391 |
| A1c | 底部导航四 Tab | **通过** · home / symptom / injection / me 截图 |
| A2 | 网络与默认行为 | **通过** · 模拟器 ping 10.0.2.2 OK；本地优先默认不强制登录 |
| A3 | 解析全链路（服务端） | **通过** · e2e:fullstack：Skill 解析 → confirm → labs 落库；二次解析 skill v1.1.0 |
| A3b | 注射排期 E2E | **通过** · 生成 15 针、due 提醒、延迟顺延 14 针 |
| A3c | 用药 E2E | **通过** · 换药链 乌帕替尼→利生奇珠，副作用记录 |
| A4 | 云密文 put / list / wipe | **通过** · sync-session → 上传 mac 密文 → 列表 → 删除 deleted=1 |
| A5 | UI 收尾 | **部分** · 应用名 IBDers、INTERNET/cleartext、深色主题跟随系统、API 默认 10.0.2.2 |

### 自动化命令（可复现）

```bash
# 服务端
node services/api/scripts/e2e-fullstack.mjs
node services/api/scripts/e2e-injection.mjs
node services/api/scripts/e2e-medication.mjs
# 应用
cd apps/mobile && flutter build apk --debug --dart-define=IBD_API_BASE=http://10.0.2.2:3000
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.ibd.ibd_mobile/.MainActivity
```

### 仍建议人工点验（UI 交互）

- [x] App 内手动录入检验（本地 SQLite/SQLCipher）— 2026-09-22 AVD：套餐多选合并 11 项，填入 12 mg/L 保存成功（`已保存 1 项到本机`）
- [x] 解析页：取消上传 → 不发起网络；同意上传 → 结果写入本机 — 选文件弹系统选择器且文案「仍不会上传」；取消回表单不上传
- [x] 设置页：SQLCipher provider / 导出 JSON / 设置备份口令 — `provider=openssl · key=已生成`；备份口令弹窗、导出/导入/删除云端按钮齐全
- [x] 模拟器通知权限：注射提醒是否弹出 — 授予 `POST_NOTIFICATIONS` 后生成 24 针排期；「系统通知测试」在通知栏弹出 IBDers
- [x] 可选「关联手机号」— 设置·云同步 opt-in 入口（非登录墙），文案强调本机存储与可注销

### 截图

`C:\dev\ibders-home.png` · `ibders-symptom.png` · `ibders-injection.png` · `ibders-me.png` · `ibders-offline.png`  
本轮点验：`var/logs/verify-*.png`（lab / settings / login / injection / notify）

---

## 结论

A 部分**主路径已在模拟器 + 服务端完成验收**：本地优先启动、离线可用、解析/注射/用药 E2E、密文同步上传删除、UI 与包名收尾。四项 UI 点验与「关联手机号」入口已完成（2026-09-22）。剩余为真机（iOS/厂商推送）。
