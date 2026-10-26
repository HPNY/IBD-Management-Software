-- 补偿脚本：本地库 v9 -> v10 迁移（bloating 历史缺陷修复）的回退/补偿
-- 任务号：T1 / T1.1（约束 §2/§5：数据库迁移须提供 up/down 或补偿脚本，修复脚本须幂等）
--
-- v10 迁移（up）做了两件事：
--   1) symptom_diaries 增加 data_flags 列（INTEGER NOT NULL DEFAULT 0）；
--   2) 将非空 bloating（历史缺陷写入的疲劳值副本）置空，并打 data_flags bit0 标记。
--
-- 本脚本（compensation/down）恢复被置空的 bloating 值：
--   脏值来源是同行 fatigue 的副本（旧代码 `bloating: _fatigue.round()`），
--   因此可从同行 fatigue 无损还原。fatigue 本身从未被 v10 修改。
--
-- 幂等性：两段 SQL 均可重复执行，结果不变。
-- 注意：SQLite 3.35 以下不支持 DROP COLUMN，data_flags 列建议保留（默认 0 不影响业务）。

-- 1) 还原被置空的 bloating（仅还原带修复标记的行）
UPDATE symptom_diaries
SET bloating = fatigue
WHERE (COALESCE(data_flags, 0) & 1) != 0
  AND bloating IS NULL;

-- 2) 清除修复标记（可选；若后续想保留审计痕迹可跳过此段）
UPDATE symptom_diaries
SET data_flags = COALESCE(data_flags, 0) & ~1
WHERE (COALESCE(data_flags, 0) & 1) != 0;
