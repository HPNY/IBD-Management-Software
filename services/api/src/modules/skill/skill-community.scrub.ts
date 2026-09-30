/**
 * T6.1 C1.2：Skill 发布前脱敏/白名单检查。
 * 只允许 ParseSkill JSON（hospital/reportType/version/dateExtraction/items）；
 * 禁止病历号、手机号、身份证、姓名字段、PDF/原始报告引用。
 */

export interface ScrubResult {
  ok: boolean;
  errors: string[];
  /** 去掉非法键后的净化内容（ok=true 时与输入语义等价的 Skill 部分）。 */
  cleaned: Record<string, unknown> | null;
}

const FORBIDDEN_KEY_RE =
  /^(name|patient|patientName|patientId|idCard|phone|mobile|pdf|file|reportText|rawText|original|attachment|birth|address|病历|姓名|电话|身份证)/i;

const PII_VALUE_RES = [
  // 18 位身份证（含 X）
  /\b\d{17}[\dXx]\b/,
  // 大陆手机号
  /\b1[3-9]\d{9}\b/,
  // 病案号样式：字母+长数字 或 「病案/住院号」后数字
  /病[案历]号[:：\s]*\d+/,
  /住院号[:：\s]*\d+/,
  /\b[A-Z]{1,3}\d{8,}\b/,
];

const ALLOWED_TOP_KEYS = new Set([
  "hospital",
  "reportType",
  "report_type",
  "version",
  "dateExtraction",
  "date_extraction",
  "items",
  "specialRules",
  "special_rules",
  "source",
]);

const ALLOWED_ITEM_KEYS = new Set([
  "name",
  "alias",
  "pattern",
  "multiline",
  "unit",
  "refMin",
  "refMax",
  "refRange",
  "ref_range",
]);

function scanValueErrors(label: string, value: unknown, errors: string[]) {
  if (typeof value === "string") {
    for (const re of PII_VALUE_RES) {
      if (re.test(value)) {
        errors.push(`${label} 可能含可识别病历/身份信息`);
        return;
      }
    }
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((v, i) => scanValueErrors(`${label}[${i}]`, v, errors));
    return;
  }
  if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      scanValueErrors(`${label}.${k}`, v, errors);
    }
  }
}

/** 检查并净化 Skill JSON；非法时 errors 非空且 cleaned=null。 */
export function scrubSkillContent(raw: unknown): ScrubResult {
  const errors: string[] = [];
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return { ok: false, errors: ["内容必须是 Skill JSON 对象"], cleaned: null };
  }
  const src = raw as Record<string, unknown>;
  for (const key of Object.keys(src)) {
    if (FORBIDDEN_KEY_RE.test(key)) {
      errors.push(`禁止字段：${key}`);
      continue;
    }
    if (!ALLOWED_TOP_KEYS.has(key)) {
      errors.push(`未知字段：${key}`);
    }
  }

  const hospital = src.hospital;
  const reportType = src.reportType ?? src.report_type;
  const version = src.version;
  const itemsRaw = src.items;
  if (typeof hospital !== "string" || !hospital.trim()) {
    errors.push("hospital 必填");
  }
  if (typeof reportType !== "string" || !reportType.trim()) {
    errors.push("reportType 必填");
  }
  if (typeof version !== "string" || !version.trim()) {
    errors.push("version 必填");
  }
  if (!Array.isArray(itemsRaw) || itemsRaw.length === 0) {
    errors.push("items 至少 1 条");
  }

  scanValueErrors("hospital", hospital, errors);
  scanValueErrors("reportType", reportType, errors);
  // 其余字段全部值扫描（alias/unit/dateExtraction 等）
  for (const [k, v] of Object.entries(src)) {
    if (k === "items") continue;
    if (k === "hospital" || k === "reportType" || k === "version") continue;
    scanValueErrors(k, v, errors);
  }

  const items: Record<string, unknown>[] = [];
  if (Array.isArray(itemsRaw)) {
    itemsRaw.forEach((it, idx) => {
      if (!it || typeof it !== "object") {
        errors.push(`items[${idx}] 必须是对象`);
        return;
      }
      const row = it as Record<string, unknown>;
      for (const key of Object.keys(row)) {
        if (FORBIDDEN_KEY_RE.test(key) && key !== "name") {
          // items.name 是检验项目名，允许；其它 name* 仍禁
          if (key !== "name") errors.push(`items[${idx}] 禁止字段：${key}`);
        }
        if (!ALLOWED_ITEM_KEYS.has(key)) {
          errors.push(`items[${idx}] 未知字段：${key}`);
        }
      }
      const name = row.name;
      const pattern = row.pattern;
      if (typeof name !== "string" || !name.trim()) {
        errors.push(`items[${idx}].name 必填`);
      }
      if (typeof pattern !== "string" || !pattern.trim()) {
        errors.push(`items[${idx}].pattern 必填`);
      }
      scanValueErrors(`items[${idx}].name`, name, errors);
      scanValueErrors(`items[${idx}].pattern`, pattern, errors);
      for (const [ik, iv] of Object.entries(row)) {
        if (ik === "name" || ik === "pattern") continue;
        scanValueErrors(`items[${idx}].${ik}`, iv, errors);
      }
      const cleanedItem: Record<string, unknown> = {
        name: typeof name === "string" ? name.trim() : name,
        pattern: typeof pattern === "string" ? pattern.trim() : pattern,
      };
      if (typeof row.alias === "string" && row.alias.trim()) {
        cleanedItem.alias = row.alias.trim();
      }
      if (typeof row.multiline === "boolean") cleanedItem.multiline = row.multiline;
      if (typeof row.unit === "string") cleanedItem.unit = row.unit;
      const refRange = row.refRange ?? row.ref_range;
      if (Array.isArray(refRange) && refRange.length === 2) {
        cleanedItem.refRange = refRange;
      }
      items.push(cleanedItem);
    });
  }

  const dateExtraction =
    (src.dateExtraction as Record<string, unknown> | undefined) ??
    (src.date_extraction as Record<string, unknown> | undefined);

  if (errors.length) return { ok: false, errors, cleaned: null };

  return {
    ok: true,
    errors: [],
    cleaned: {
      hospital: (hospital as string).trim(),
      reportType: (reportType as string).trim(),
      version: (version as string).trim(),
      dateExtraction: dateExtraction ?? { primary: "" },
      items,
      source: "community",
    },
  };
}
