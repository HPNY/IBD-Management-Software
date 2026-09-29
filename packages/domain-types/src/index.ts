/** 共享领域类型（MVP）。中文规范指标名以 PRD 2.1.3 为准。 */

export type IbdType = "crohns" | "uc";

export type LabSource = "skill" | "ai" | "manual";

export type MedStatus = "active" | "paused" | "stopped";

export type InjectionPhase = "induction" | "maintenance";

export type BristolType = 1 | 2 | 3 | 4 | 5 | 6 | 7;

export type FlareLevel = "green" | "yellow" | "red";

/** IBD 核心指标中文规范名 */
export const CORE_LAB_NAMES = [
  "超敏C反应蛋白",
  "血沉",
  "粪便钙卫蛋白",
  "淋巴细胞",
  "白蛋白",
  "血红蛋白",
  "尿酸",
] as const;

export type CoreLabName = (typeof CORE_LAB_NAMES)[number];

export interface PatientBasicInfo {
  name: string;
  sex: "male" | "female" | "other";
  birthDate: string;
  diagnosisDate: string;
  ibdType: IbdType;
}

export interface LabItem {
  nameNorm: string;
  nameRaw: string;
  value: number;
  unit?: string;
  refMin?: number;
  refMax?: number;
  flag?: "high" | "low" | null;
}

export interface LabResult {
  id: string;
  patientId: string;
  date: string;
  hospital?: string;
  items: LabItem[];
  source: LabSource;
  hlc: string;
  deviceId: string;
}

export interface Medication {
  id: string;
  patientId: string;
  drugName: string;
  brandName?: string;
  category?: string;
  dosage: string;
  frequency: string;
  route: "oral" | "sc" | "iv";
  startDate: string;
  endDate?: string;
  status: MedStatus;
  reason?: string;
}

export interface Injection {
  id: string;
  patientId: string;
  drug: string;
  plannedDate: string;
  actualDate?: string;
  phase: InjectionPhase;
  dose: string;
  route: "sc" | "iv";
  weekNumber: number;
  notes?: string;
}

export interface SymptomDiary {
  id: string;
  patientId: string;
  date: string;
  painLevel?: number;
  diarrheaCount?: number;
  stoolType?: BristolType;
  bloodyStool?: "none" | "trace" | "obvious";
  bloating?: number;
  fatigue?: number;
  nausea?: boolean;
  overallFeeling?: "better" | "same" | "worse";
  /** 排便细表字段并入打卡，避免重复填写 */
  urgency?: boolean;
  mucus?: boolean;
  bowelCount?: number;
  /** G2 日记补全 */
  oralUlcer?: boolean;
  jointPain?: boolean;
  /** 部位，逗号分隔（膝/踝/手/背/其他） */
  jointPainSite?: string;
  /** 自定义关注项 JSON：[{label,value}] */
  customItems?: string;
  /** G4 睡眠/压力每日打卡 */
  sleepHours?: number;
  sleepQuality?: number;
  sleepInsomnia?: boolean;
  nightWakes?: number;
  stressLevel?: number;
  stressSource?: string;
}

export interface BathroomRecord {
  id: string;
  patientId?: string;
  dateTime: string;
  dailyCount?: number;
  stoolType?: BristolType;
  urgency?: boolean;
  /** 0=无 1=擦拭有 2=明显 */
  blood?: 0 | 1 | 2;
  mucus?: boolean;
  diarrheaCount?: number;
  /** manual=细表手记 checkin=打卡同步 */
  source?: "manual" | "checkin";
  notes?: string;
}

export interface ParseSkillItemRule {
  name: string;
  alias?: string;
  pattern: string;
  multiline?: boolean;
  unit?: string;
  refRange?: [number, number];
}

export interface ParseSkill {
  hospital: string;
  reportType: string;
  version: string;
  dateExtraction: { primary: string; fallback?: string };
  items: ParseSkillItemRule[];
}
