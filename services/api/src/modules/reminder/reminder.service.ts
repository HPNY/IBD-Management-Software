import { Injectable } from "@nestjs/common";

export interface ReminderRule {
  id: string;
  patientId: string;
  kind: "injection" | "medication" | "followup";
  leadDays: number;
  enabled: boolean;
}

@Injectable()
export class ReminderService {
  private rules = new Map<string, ReminderRule>();

  list(patientId: string): ReminderRule[] {
    return [...this.rules.values()].filter((r) => r.patientId === patientId);
  }

  create(dto: Omit<ReminderRule, "id">): ReminderRule {
    const id = `rem_${Date.now()}`;
    const rule = { ...dto, id };
    this.rules.set(id, rule);
    return rule;
  }
}
