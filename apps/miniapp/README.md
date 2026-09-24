# Taro 小程序（IBDers 轻量入口）

与 PC 同用 React + TypeScript。类型来自 `@ibd/domain-types`，HTTP 客户端来自 `@ibd/api-client`。

## MVP 页

| 页 | 路径 | 说明 |
|----|------|------|
| 首页 | `pages/index` | 入口导航 + 本地 `app_user_uuid` |
| 检验查看 | `pages/labs` | 核心指标列表（连 API） |
| 简化打卡 | `pages/checkin` | 腹痛/排便/Bristol/整体，本机存储 |
| 注射提醒 | `pages/injection` | 近期针次列表 |
| 就诊摘要 | `pages/summary` | 生成并复制分享 |

不做：PDF 解析、独立排便、年度报告。

## 运行

```bash
cd apps/miniapp
npm install
npm run dev:weapp    # 微信开发者工具打开 dist/
npm run build:weapp
```

API 基址：`IBD_API_BASE`（默认 `http://127.0.0.1:3000`）。

## 状态

- **T3.1 脚手架**：已就绪（Taro 3 + React + api-client）
- **T3.2 MVP 四页**：已实现
- **T3.3 微信登录 + 订阅消息**：待做
