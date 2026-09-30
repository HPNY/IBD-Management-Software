---
feature: c-enhance-ui
status: delivered
updated: 2026-09-23
branch: feature/c-enhance-ui
commits: 5663b17..HEAD
---

# C 增强：社区 UI 接线 + D4 日历窗口

## Report

**What was built** — D4 增加日历窗口 `avg30Days`/`avg90Days`（按日期过滤，稀疏样本不被点窗口误导）；同城页接 `geo-community` 城市计数/帖流/发帖，失败降级本机草稿。

**Verification** — `flutter test` PASS **98**（含日历窗口用例）。

**Journey log** — 点窗口与日历窗口在稀疏采样下语义不同，UI 标注「（按点）」避免误读。

## [S1] Problem

- D3 同城页仅有本地帖演示，未接 `geo-community` 城市计数/帖流 API。
- D4 趋势 `avg30`/`avg90` 为末 N 个**点**均值，不是「近 30/90 **日**」；样本稀疏时语义失真。

## [S2] Design

### S2.1 D4 日历窗口

- `summarizeSeries` 增加可选 `asOf` 与按日期过滤：`avgLastNDays(values, dates, n, asOf)`。
- UI 标签改为「近 30 日均 / 近 90 日均」；无日期时回退点数窗口并标注「（按点）」。
- 单测：同一序列有点缺失时日历窗口 ≠ 点窗口。

### S2.2 App 社区接线

- `IbdApiClient` 增加 `geoCities` / `geoPosts` / `createGeoPost`。
- `GeoCommunityPage`：加载城市计数；发帖走 API；失败降级本地列表并提示。
- 隐私：payload 仅 city/nickname/content（无位置字段）。

## [S3] Out of Scope

- Skill 积分、医生端摘要全量、真机抓包

## Tasks

- [x] T1: D4 日历窗口均值 + 单测 — acceptance: 30/90 日过滤正确 (covers: S2.1)
- [x] T2: geo API 客户端 + 页面接线 — acceptance: 有网拉帖/发帖，失败降级 (covers: S2.2)
