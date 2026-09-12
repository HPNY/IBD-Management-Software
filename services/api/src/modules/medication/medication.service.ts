import { Injectable } from "@nestjs/common";

export interface MedicationRecord {
  id: string;
  patientId: string;
  drugName: string;
  dosage: string;
  frequency: string;
  route: "oral" | "sc" | "iv";
  startDate: string;
  endDate?: string;
  status: "active" | "paused" | "stopped";
  reason?: string;
}

@Injectable()
export class MedicationService {
  private store = new Map<string, MedicationRecord>();

  list(patientId: string): MedicationRecord[] {
    return [...this.store.values()].filter((m) => m.patientId === patientId);
  }

  create(dto: Omit<MedicationRecord, "id">): MedicationRecord {
    const id = `med_${Date.now()}`;
    const record = { ...dto, id };
    this.store.set(id, record);
    return record;
  }
}
