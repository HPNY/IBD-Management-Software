/**
 * T2：检验来源标记（LabResult.source）判定纯函数。
 *
 * 目标：`skill | ai | manual` 三值如实反映真实来源——
 * - `skill`：Skill 模板命中解析；
 * - `ai`：LLM/Vision 兜底解析；
 * - `manual`：纯手填（不经解析任务，由客户端直接写）。
 *
 * 兼容策略（裁决④：旧数据不回填）：历史任务 `engine` 列为空（迁移前）时，
 * 以 `skillVersionId` 是否存在回退判定（Skill 命中才会写 skillVersion），
 * 其余按 `ai` 处理——与修复前客户端行为一致，不追溯修改已入库数据。
 */
export type ParsedSource = "skill" | "ai";

export function normalizeParseEngine(
  engine: string | null | undefined,
): ParsedSource | null {
  const e = (engine ?? "").trim().toLowerCase();
  if (e.startsWith("skill")) return "skill";
  if (e.startsWith("ai")) return "ai";
  return null;
}

export function resolveLabSource(job: {
  engine?: string | null;
  skillVersionId?: string | null;
}): ParsedSource {
  const normalized = normalizeParseEngine(job.engine);
  if (normalized) return normalized;
  // 旧任务兼容回退（engine 列为空的历史数据）
  return job.skillVersionId ? "skill" : "ai";
}
