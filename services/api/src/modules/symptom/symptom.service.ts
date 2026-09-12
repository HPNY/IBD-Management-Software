import { Injectable } from "@nestjs/common";

/** MVP：症状日记字段；独立排便流水表 BathroomRecord 属 V1.0。 */
export interface SymptomDiaryRecord {
  id: string;
  patientId: string;
  date: string;
  painLevel?: number;
  diarrheaCount?: number;
  stoolType?: 1 | 2 | 3 | 4 | 5 | 6 | 7;
  bloodyStool?: "none" | "trace" | "obvious";
  bloating?: number;
  fatigue?: number;
  nausea?: boolean;
  overallFeeling?: "better" | "same" | "worse";
}

@Injectable()
export class SymptomService {
  private store = new Map<string, SymptomDiaryRecord>();

  list(patientId: string): SymptomDiaryRecord[] {
    return [...this.store.values()]
      .filter((s) => s.patientId === patientId)
      .sort((a, b) => b.date.localeCompare(a.date));
  }

  upsert(dto: SymptomDiaryRecord): SymptomDiaryRecord {
    const key = `${dto.patientId}:${dto.date}`;
    const existing = [...this.store.values()].find(
      (s) => `${s.patientId}:${s.date}` === key,
    );
    if (existing) {
      const merged = { ...existing, ...dto, id: existing.id };
      this.store.set(existing.id, merged);
      return merged;
    }
    const id = `symp_${Date.now()}`;
    const record = { ...dto, id };
    this.store.set(id, record);
    return record;
  }
}
