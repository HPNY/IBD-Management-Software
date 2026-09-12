import { Injectable } from "@nestjs/common";

export interface InjectionRecord {
  id: string;
  patientId: string;
  drug: string;
  plannedDate: string;
  actualDate?: string;
  phase: "induction" | "maintenance";
  dose: string;
  route: "sc" | "iv";
  weekNumber: number;
  notes?: string;
}

@Injectable()
export class InjectionService {
  private store = new Map<string, InjectionRecord>();

  list(patientId: string): InjectionRecord[] {
    return [...this.store.values()]
      .filter((i) => i.patientId === patientId)
      .sort((a, b) => a.plannedDate.localeCompare(b.plannedDate));
  }

  create(dto: Omit<InjectionRecord, "id">): InjectionRecord {
    const id = `inj_${Date.now()}`;
    const record = { ...dto, id };
    this.store.set(id, record);
    return record;
  }
}
