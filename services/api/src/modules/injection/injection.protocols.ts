/** 生物制剂排期协议（PRD §2.2.3）。按周次相对 startDate。 */
export type InjectionRoute = "sc" | "iv";

export interface ProtocolSlot {
  /** 相对起始日的周次 */
  week: number;
  route: InjectionRoute;
  phase: "induction" | "maintenance";
  dose: string;
  label?: string;
}

export interface InjectionProtocol {
  drugKey: string;
  drugName: string;
  /** 诱导期固定点 */
  induction: ProtocolSlot[];
  /** 维持期：起始周次 + 间隔周 */
  maintenance: {
    startWeek: number;
    intervalWeeks: number;
    route: InjectionRoute;
    dose: string;
  };
  /** 生成多少次维持（默认 12 次 ≈ 2 年） */
  maintenanceCount?: number;
}

export const PROTOCOLS: Record<string, InjectionProtocol> = {
  skyrizi: {
    drugKey: "skyrizi",
    drugName: "利生奇珠单抗（喜开悦）",
    induction: [
      { week: 0, route: "iv", phase: "induction", dose: "600mg", label: "静脉诱导 W0" },
      { week: 4, route: "iv", phase: "induction", dose: "600mg", label: "静脉诱导 W4" },
      { week: 8, route: "iv", phase: "induction", dose: "600mg", label: "静脉诱导 W8" },
    ],
    maintenance: {
      startWeek: 12,
      intervalWeeks: 8,
      route: "sc",
      dose: "180mg",
    },
    maintenanceCount: 12,
  },
  humira: {
    drugKey: "humira",
    drugName: "阿达木单抗（修美乐）",
    induction: [
      { week: 0, route: "sc", phase: "induction", dose: "160mg", label: "首剂" },
      { week: 2, route: "sc", phase: "induction", dose: "80mg" },
    ],
    maintenance: {
      startWeek: 4,
      intervalWeeks: 2,
      route: "sc",
      dose: "40mg",
    },
    maintenanceCount: 24,
  },
  stelara: {
    drugKey: "stelara",
    drugName: "乌司奴单抗（喜达诺）",
    induction: [
      { week: 0, route: "iv", phase: "induction", dose: "体重按说明书", label: "静脉诱导" },
    ],
    maintenance: {
      startWeek: 8,
      intervalWeeks: 8,
      route: "sc",
      dose: "90mg",
    },
    maintenanceCount: 12,
  },
  entyvio: {
    drugKey: "entyvio",
    drugName: "维得利珠单抗（安吉优）",
    induction: [
      { week: 0, route: "iv", phase: "induction", dose: "300mg" },
      { week: 2, route: "iv", phase: "induction", dose: "300mg" },
      { week: 6, route: "iv", phase: "induction", dose: "300mg" },
    ],
    maintenance: {
      startWeek: 8,
      intervalWeeks: 8,
      route: "iv",
      dose: "300mg",
    },
    maintenanceCount: 12,
  },
};

export function getProtocol(drugKey: string): InjectionProtocol | null {
  return PROTOCOLS[drugKey] ?? null;
}

export function listProtocols() {
  return Object.values(PROTOCOLS).map((p) => ({
    drugKey: p.drugKey,
    drugName: p.drugName,
    induction: p.induction,
    maintenance: p.maintenance,
  }));
}

export function addWeeks(isoDate: string, weeks: number): string {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + weeks * 7);
  return d.toISOString().slice(0, 10);
}
