/** T6.2 M3.2：就诊摘要文本组装（对齐 App VisitSummaryPage._build）。 */

export interface VisitSummaryLabItem {
  nameNorm?: string;
  name?: string;
  value?: number | string;
  unit?: string | null;
}

export interface VisitSummaryLab {
  date?: string | null;
  items?: VisitSummaryLabItem[];
}

export interface VisitSummaryMed {
  drugName?: string | null;
  drug_name?: string | null;
  dosage?: string | null;
  frequency?: string | null;
  status?: string | null;
}

export interface VisitSummaryInjection {
  drug?: string | null;
  plannedDate?: string | null;
  planned_date?: string | null;
  dose?: string | null;
}

export interface VisitSummarySymptom {
  date?: string | null;
  painLevel?: number | null;
  pain_level?: number | null;
  diarrheaCount?: number | null;
  diarrhea_count?: number | null;
  bowelCount?: number | null;
  bowel_count?: number | null;
  stoolType?: number | null;
  stool_type?: number | null;
  bloodyStool?: string | null;
  bloody_stool?: string | null;
  urgency?: number | boolean | null;
  mucus?: number | boolean | null;
}

export function buildVisitSummaryText(input: {
  meds: VisitSummaryMed[];
  labs: VisitSummaryLab[];
  injections: VisitSummaryInjection[];
  symptoms: VisitSummarySymptom[];
  ibdType?: string | null;
  now?: Date;
}): string {
  const now = input.now ?? new Date();
  const dateStr = now.toISOString().slice(0, 10);

  const medLine = input.meds
    .map((m) => {
      const drug = m.drugName ?? m.drug_name ?? "";
      return `${drug} ${m.dosage ?? ""} ${m.frequency ?? ""}`.trim();
    })
    .filter(Boolean)
    .join("\n");

  // 最近一次检验的 items 展示（对齐 App：latestCore 风格，取最后一份 lab 的前 6 项）
  const latestLab = input.labs[0];
  const labLine = (latestLab?.items ?? [])
    .slice(0, 6)
    .map((i) => {
      const name = i.nameNorm ?? i.name ?? "";
      return `${name}=${i.value ?? ""}${i.unit ?? ""}`;
    })
    .join("  ");

  const injLine = input.injections
    .slice(0, 3)
    .map((r) => {
      const drug = r.drug ?? "";
      const planned = r.plannedDate ?? r.planned_date ?? "";
      return `${drug} ${planned} ${r.dose ?? ""}`.trim();
    })
    .filter(Boolean)
    .join("\n");

  const last = input.symptoms[0];
  let symptomLine = "（近期未打卡）";
  if (last) {
    const blood = (last.bloodyStool ?? last.bloody_stool ?? "none") as string;
    const bloodLabel =
      blood === "obvious" ? "明显" : blood === "trace" ? "擦拭有" : "无";
    const urgencyRaw = last.urgency ?? 0;
    const urgency = urgencyRaw === 1 || urgencyRaw === true ? "紧迫" : "无紧迫";
    const mucusRaw = last.mucus ?? 0;
    const mucus = mucusRaw === 1 || mucusRaw === true ? "有黏液" : "无黏液";
    const pain = last.painLevel ?? last.pain_level ?? "-";
    const bowel = last.bowelCount ?? last.bowel_count ?? "-";
    const diarrhea = last.diarrheaCount ?? last.diarrhea_count ?? "-";
    const bristol = last.stoolType ?? last.stool_type ?? "-";
    symptomLine = `腹痛 ${pain}/10 · 排便 ${bowel} 次 · 腹泻 ${diarrhea} 次 · Bristol ${bristol} · 便血 ${bloodLabel} · ${urgency} · ${mucus}`;
  }

  return [
    "【就诊摘要 · IBDers 生成】",
    `日期：${dateStr}`,
    input.ibdType ? `诊断类型：${input.ibdType}` : null,
    "",
    "【当前用药】",
    medLine || "（未记录）",
    "",
    `【最近检验（${latestLab?.date ?? "无"}）】`,
    labLine || "（未录入检验项）",
    "",
    "【近期注射】",
    injLine || "（暂无待注射）",
    "",
    "【症状】",
    symptomLine,
    "",
    "【关注】",
    "- 数据来自患者授权范围，请结合临床判断",
  ]
    .filter((x) => x !== null)
    .join("\n");
}
