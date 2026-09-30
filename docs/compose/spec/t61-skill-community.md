---
feature: t61-skill-community
status: designed
updated: 2026-09-23
branch: feature/t61-t62-breakdown
commits: cac1a8d
---

# T6.1 Skill 社区拆解：匿名模板发布 / 评分 / 协作更新

## Report

**What was built** — T6.1 权威拆解：Skill 社区四阶段子包 C1–C4（本地候选→发布→浏览评分→协作升版），每阶段 3–5 个可验收任务。固定「只收 Skill JSON、不收原始报告」隐私契约；与 G5 Web Skill 表单、T6.2 医生端边界对齐。本 spec 只拆解不实施。

**Verification** — 对照 PRD §5.3、architecture S2.3.4 ParseSkill 版本化、local-first C 类；worklist T6.1 已指向本 spec。无代码变更。

**Journey log** — 解析确认后自动生成 Skill 的链路在 parse-worker/`ParseSkill` 已有雏形；社区层补齐「匿名发布、评分、协作版本」。积分/荣誉可后置，不挡 MVP。

## [S1] Problem

worklist **T6.1**「Skill 社区（匿名模板发布 / 评分 / 协作更新）」未拆分，无法按会话验收。PRD §5.3 要求：解析确认 → 自动 Skill → 发布社区 → 评分优选 → 格式更新协作升版。必须**不含原始病历/报告**（local-first C 类），与已交付的 Web `/skills` 本地表单、parse-worker 样例 Skill 衔接。

## [S2] Design — 四阶段子包

**总原则**
- **匿名**：发布者用 `app_user_uuid` 哈希 + 昵称可选；无真实姓名。
- **内容白名单**：仅 `ParseSkill` JSON（hospital / reportType / version / dateExtraction / items[] / specialRules?）；**禁止** PDF、报告截图、患者姓名、检验值样本原文（fixture 假数据可）。
- **版本不可变**：沿用 architecture「Skill 不可变，只追加 ParseSkillVersion」；协作更新=新版本 + 评分。
- 服务端 Nest 增 community 模块；App/Web 消费。与 T6.4 D2 药评社区共享「匿名发布」纪律但**表与 API 分离**。

### S2.1 C1 · 本地候选 Skill 与发布草稿

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| C1.1 | 解析确认后自动落「本地 Skill 候选」（或复用 parse-worker auto ParseSkill）并可在 App/Web 列表查看 | 确认一次解析后出现候选（hospital/reportType/items） (covers: S2.1) | — |
| C1.2 | 发布前脱敏检查：过滤/提示非法字段（姓名、病历号、原始 PDF 引用） | 有病历号样式字符串时阻止发布并提示 (covers: S2.1; depends: C1.1) | C1.1 |
| C1.3 | 发布草稿：匿名昵称（可选）+ 目标医院/报告类型确认 | 保存草稿 JSON 到本地，未上传 (covers: S2.1; depends: C1.2) | C1.2 |

### S2.2 C2 · 社区发布 API

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| C2.1 | `POST /skill-community/skills`：匿名鉴权 scope，白名单校验 JSON schema | 非法 schema 400；合法 201 带 version=1 (covers: S2.2) | C1.3 |
| C2.2 | 发布写 `parse_skill_versions` 追加（不可变） | 同 skill 重复发布新版本号 (covers: S2.2; depends: C2.1) | C2.1 |
| C2.3 | 隐私测试：请求/存储无报告原文键 | 测试断言 payload 键集 (covers: S2.2; depends: C2.1) | C2.1 |

### S2.3 C3 · 浏览 / 评分 / 使用

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| C3.1 | 社区搜索：按 hospital/reportType 列表 + 详情（items 预览） | 可检索并查看版本与统计 (covers: S2.3; depends: C2.1) | C2.1 |
| C3.2 | 评分（1–5）与短评（可选）；聚合均分/条数 | 评分后聚合更新；每人每 skill 一评可改 (covers: S2.3; depends: C3.1) | C3.1 |
| C3.3 | 「使用此 Skill」：导入到本地/我的 Skill，解析优先命中 | 导入后下次解析路由可命中该版本 (covers: S2.3; depends: C3.1) | C3.1 |
| C3.4 | App 或 Web 社区入口页（与 `/skills` 管理并列） | 入口可达社区列表 (covers: S2.3; depends: C3.1) | C3.1 |

### S2.4 C4 · 协作更新与优选

| ID | 任务 | 验收（covers） | depends |
|----|------|----------------|---------|
| C4.1 | 「协作更新」：基于他人 skill 提交新 items/规则 diff → 新版本 | 新版本可追溯 parent version (covers: S2.4; depends: C2.2, C3.1) | C2.2, C3.1 |
| C4.2 | 优选排序：均分 × 使用量，高亮 Top | 列表默认按综合分排序 (covers: S2.4; depends: C3.2) | C3.2 |
| C4.3 | （可选）贡献积分/荣誉徽章 | 发布/升版可见计数 (covers: S2.4; depends: C4.1) | C4.1 |

### S2.5 边界

- 不做：真实病历共享、Skill 付费、医院官方认证、Top50 覆盖运营（属运营目标）。
- 不改：PDF 解析主路径行为（仅增加社区来源 Skill）。
- 积分/推荐算法最小化，可砍。

## [S3] Out of Scope

见 [S2.5]；另：本 spec 只拆解不实施；实施按 C1→C2→C3→C4 另开 compose。

## Tasks

- [ ] T1: C1 本地候选与发布草稿按 S2.1 实施 — acceptance: C1.1–C1.3 全勾 (covers: S2.1)
- [ ] T2: C2 发布 API 按 S2.2 实施 — acceptance: C2.1–C2.3 全勾 (covers: S2.2; depends: T1)
- [ ] T3: C3 浏览评分使用按 S2.3 实施 — acceptance: C3.1–C3.4 全勾 (covers: S2.3; depends: T2)
- [ ] T4: C4 协作与优选按 S2.4 实施 — acceptance: C4.1–C4.2 全勾（C4.3 可选） (covers: S2.4; depends: T3)
