import type { LabItemDto } from "@ibd/api-client";

/**
 * C3：worker 返回 snake_case（name/name_raw/ref_min），
 * confirm 契约要 camelCase（nameNorm/nameRaw/refMin）。
 *
 * 直接透传会导致 `nameNorm` 为空、confirm 必失败；定性项（value=null）
 * 与运算符值（>1800）也必须过滤，不能写回 0 或 NaN。
 */
export function toLabItem(raw: unknown): LabItemDto | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const nameNorm = String(r.nameNorm ?? r.name_norm ?? r.name ?? "").trim();
  if (!nameNorm) return null;

  const num = (v: unknown): number | undefined => {
    if (v === null || v === undefined || v === "") return undefined;
    const n = typeof v === "number" ? v : Number(v);
    return Number.isFinite(n) ? n : undefined;
  };

  const value = num(r.value);
  if (value === undefined) return null; // 定性/运算符值不写回数值列

  const flag = r.flag === "high" || r.flag === "low" ? r.flag : null;
  return {
    nameNorm,
    nameRaw: String(r.nameRaw ?? r.name_raw ?? nameNorm),
    value,
    unit: (r.unit as string | null | undefined) ?? undefined,
    refMin: num(r.refMin ?? r.ref_min),
    refMax: num(r.refMax ?? r.ref_max),
    flag,
  };
}

/** 批量映射，丢弃不可写回的条目（定性、NaN、缺名）。 */
export function toLabItems(raw: unknown[] | null | undefined): LabItemDto[] {
  return (raw ?? []).map(toLabItem).filter((i): i is LabItemDto => i !== null);
}
