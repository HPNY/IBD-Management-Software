import { Injectable } from "@nestjs/common";
import { hlcCompare, type Hlc } from "../../common/hlc";

export interface SyncPushItem {
  entity: string;
  entityId: string;
  deviceId: string;
  hlc: Hlc;
  payload: unknown;
}

/**
 * MVP：基于 HLC 的乐观锁骨架；持久化与全量拉取后续接 Postgres。
 */
@Injectable()
export class SyncService {
  private heads = new Map<string, Hlc>();

  push(items: SyncPushItem[]) {
    const accepted: string[] = [];
    const conflicted: string[] = [];
    for (const item of items) {
      const key = `${item.entity}:${item.entityId}`;
      const last = this.heads.get(key);
      if (!last || hlcCompare(item.hlc, last) > 0) {
        this.heads.set(key, item.hlc);
        accepted.push(key);
      } else {
        conflicted.push(key);
      }
    }
    return { accepted, conflicted };
  }
}
