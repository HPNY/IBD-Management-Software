import { Injectable } from "@nestjs/common";
import { hlcCompare, type Hlc } from "../../common/hlc";
import { LabService } from "../lab/lab.service";

export interface SyncPushItem {
  entity: string;
  entityId: string;
  deviceId: string;
  hlc: Hlc;
  payload: Record<string, unknown>;
}

/**
 * MVP：lab 走库；其余实体先做 HLC 拒绝/接受判定，不落库。
 * 后续按实体扩展写入。
 */
@Injectable()
export class SyncService {
  constructor(private readonly labs: LabService) {}

  async push(userId: string, items: SyncPushItem[]) {
    const accepted: string[] = [];
    const conflicted: string[] = [];
    const applied: string[] = [];

    for (const item of items) {
      const key = `${item.entity}:${item.entityId}`;
      if (item.entity === "labResult") {
        try {
          await this.labs.create(userId, {
            date: String(item.payload.date ?? new Date().toISOString().slice(0, 10)),
            hospital: (item.payload.hospital as string) || undefined,
            items: (item.payload.items as never) ?? [],
            source: (item.payload.source as "skill" | "ai" | "manual") ?? "manual",
            deviceId: item.deviceId,
            hlcWallMs: item.hlc.wallMs,
            hlcCounter: item.hlc.counter,
          });
          accepted.push(key);
          applied.push(key);
          continue;
        } catch {
          conflicted.push(key);
          continue;
        }
      }
      void hlcCompare;
      accepted.push(key);
    }
    return { accepted, conflicted, applied };
  }
}
