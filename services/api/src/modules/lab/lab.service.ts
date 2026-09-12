import { Injectable } from "@nestjs/common";
import { hlcNow, type Hlc } from "../../common/hlc";

export interface LabItemDto {
  nameNorm: string;
  nameRaw?: string;
  value: number;
  unit?: string;
  refMin?: number;
  refMax?: number;
}

export interface CreateLabDto {
  patientId: string;
  date: string;
  hospital?: string;
  items: LabItemDto[];
  source?: "skill" | "ai" | "manual";
  deviceId: string;
}

export interface LabResultRecord extends CreateLabDto {
  id: string;
  source: "skill" | "ai" | "manual";
  hlc: Hlc;
}

@Injectable()
export class LabService {
  private store = new Map<string, LabResultRecord>();

  list(patientId: string): LabResultRecord[] {
    return [...this.store.values()].filter((r) => r.patientId === patientId);
  }

  create(dto: CreateLabDto): LabResultRecord {
    const id = `lab_${Date.now()}`;
    const record: LabResultRecord = {
      ...dto,
      id,
      source: dto.source ?? "manual",
      hlc: hlcNow(dto.deviceId),
    };
    this.store.set(id, record);
    return record;
  }
}
