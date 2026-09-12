/**
 * 混合逻辑时钟（HLC）。定稿见架构文档 S2.5。
 * 骨架阶段仅提供工具函数；持久化在 Sync 模块接入。
 */
export interface Hlc {
  wallMs: number;
  counter: number;
  deviceId: string;
}

export function hlcNow(deviceId: string, last?: Hlc): Hlc {
  const wallMs = Date.now();
  if (!last || wallMs > last.wallMs) {
    return { wallMs, counter: 0, deviceId };
  }
  return { wallMs: last.wallMs, counter: last.counter + 1, deviceId };
}

export function hlcCompare(a: Hlc, b: Hlc): number {
  if (a.wallMs !== b.wallMs) return a.wallMs - b.wallMs;
  if (a.counter !== b.counter) return a.counter - b.counter;
  return a.deviceId < b.deviceId ? -1 : a.deviceId > b.deviceId ? 1 : 0;
}
