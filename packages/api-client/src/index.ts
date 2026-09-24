// 共享 API 客户端（小程序 / PC Web / 医生端）
// 类型来自 @ibd/domain-types；契约见 openapi.yaml

export const API_BASE =
  (typeof process !== "undefined" && process.env?.IBD_API_BASE) ||
  "http://localhost:3000";

export interface ApiClientOptions {
  baseUrl?: string;
  accessToken?: string;
  appUserId?: string;
  fetchImpl?: typeof fetch;
}

export interface LabItemDto {
  nameNorm: string;
  nameRaw?: string;
  value: number;
  unit?: string;
  refMin?: number;
  refMax?: number;
  flag?: "high" | "low" | null;
}

export interface ParseJobDto {
  id: string;
  status: string;
  objectKey: string;
  items?: unknown[];
  sourceDeleted?: boolean;
  error?: string | null;
}

export class IbdApiClient {
  readonly baseUrl: string;
  private accessToken: string | null;
  readonly appUserId: string | null;
  private readonly fetchImpl: typeof fetch;

  constructor(opts: ApiClientOptions = {}) {
    this.baseUrl = (opts.baseUrl ?? API_BASE).replace(/\/$/, "");
    this.accessToken = opts.accessToken ?? null;
    this.appUserId = opts.appUserId ?? null;
    this.fetchImpl =
      opts.fetchImpl ??
      ((input, init) => fetch(input, init));
  }

  setToken(token: string | null) {
    this.accessToken = token;
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    const res = await this.fetchImpl(`${this.baseUrl}${path}`, {
      method,
      headers: {
        ...(body != null ? { "content-type": "application/json" } : {}),
        ...(this.accessToken
          ? { authorization: `Bearer ${this.accessToken}` }
          : {}),
      },
      body: body != null ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`${method} ${path} → ${res.status} ${text}`);
    }
    return (await res.json()) as T;
  }

  /** 短时解析会话（单次上传） */
  parseSession(): Promise<{ accessToken: string; expiresAt?: string }> {
    return this.request("POST", "/api/v1/auth/parse-session", {
      appUserId: this.appUserId,
    });
  }

  /** 短时同步会话 */
  syncSession(): Promise<{ accessToken: string; expiresAt?: string }> {
    return this.request("POST", "/api/v1/auth/sync-session", {
      appUserId: this.appUserId,
    });
  }

  /** 短时推送会话 */
  pushSession(): Promise<{ accessToken: string; expiresAt?: string }> {
    return this.request("POST", "/api/v1/auth/push-session", {
      appUserId: this.appUserId,
    });
  }

  presign(input: {
    filename: string;
    contentType?: string;
    expiresInSec?: number;
  }): Promise<{
    objectKey: string;
    uploadUrl: string;
    method: string;
    headers: Record<string, string>;
    expiresAt: string;
    driver: string;
  }> {
    return this.request("POST", "/api/v1/files/presign", input);
  }

  enqueueParse(input: {
    objectKey: string;
    hospitalHint?: string;
    reportType?: string;
  }): Promise<ParseJobDto> {
    return this.request("POST", "/api/v1/parse/jobs", input);
  }

  /** PUT 字节到 presign 返回的 uploadUrl（local HMAC / S3 预签名） */
  async uploadBytes(
    presign: { uploadUrl: string; method: string; headers: Record<string, string> },
    bytes: Uint8Array,
  ): Promise<void> {
    const res = await this.fetchImpl(presign.uploadUrl, {
      method: presign.method || "PUT",
      headers: { ...presign.headers },
      body: bytes as unknown as BodyInit,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`upload failed: ${res.status} ${text}`);
    }
  }

  /** 轮询至 done/failed */
  async waitParseJob(
    id: string,
    opts: { intervalMs?: number; timeoutMs?: number } = {},
  ): Promise<ParseJobDto> {
    const interval = opts.intervalMs ?? 2000;
    const deadline = Date.now() + (opts.timeoutMs ?? 120000);
    for (;;) {
      const job = await this.getParseJob(id);
      if (job.status === "done" || job.status === "failed") return job;
      if (Date.now() > deadline) throw new Error(`parse job ${id} timeout`);
      await new Promise((r) => setTimeout(r, interval));
    }
  }

  /** PUT 字节到 presign 返回的 uploadUrl（local HMAC / S3 预签名） */
  async uploadBytes(
    presign: { uploadUrl: string; method: string; headers: Record<string, string> },
    bytes: Uint8Array,
  ): Promise<void> {
    const res = await this.fetchImpl(presign.uploadUrl, {
      method: presign.method || "PUT",
      headers: { ...presign.headers },
      body: bytes as unknown as BodyInit,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`upload failed: ${res.status} ${text}`);
    }
  }

  /** 轮询至 done/failed */
  async waitParseJob(
    id: string,
    opts: { intervalMs?: number; timeoutMs?: number } = {},
  ): Promise<ParseJobDto> {
    const interval = opts.intervalMs ?? 2000;
    const deadline = Date.now() + (opts.timeoutMs ?? 120000);
    for (;;) {
      const job = await this.getParseJob(id);
      if (job.status === "done" || job.status === "failed") return job;
      if (Date.now() > deadline) throw new Error(`parse job ${id} timeout`);
      await new Promise((r) => setTimeout(r, interval));
    }
  }

  /** PUT 字节到 presign 返回的 uploadUrl（local HMAC / S3 预签名） */
  async uploadBytes(
    presign: { uploadUrl: string; method: string; headers: Record<string, string> },
    bytes: Uint8Array,
  ): Promise<void> {
    const res = await this.fetchImpl(presign.uploadUrl, {
      method: presign.method || "PUT",
      headers: { ...presign.headers },
      body: bytes as unknown as BodyInit,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`upload failed: ${res.status} ${text}`);
    }
  }

  /** 轮询至 done/failed */
  async waitParseJob(
    id: string,
    opts: { intervalMs?: number; timeoutMs?: number } = {},
  ): Promise<ParseJobDto> {
    const interval = opts.intervalMs ?? 2000;
    const deadline = Date.now() + (opts.timeoutMs ?? 120000);
    for (;;) {
      const job = await this.getParseJob(id);
      if (job.status === "done" || job.status === "failed") return job;
      if (Date.now() > deadline) throw new Error(`parse job ${id} timeout`);
      await new Promise((r) => setTimeout(r, interval));
    }
  }

  /** PUT 字节到 presign 返回的 uploadUrl（local HMAC / S3 预签名） */
  async uploadBytes(
    presign: { uploadUrl: string; method: string; headers: Record<string, string> },
    bytes: Uint8Array,
  ): Promise<void> {
    const res = await this.fetchImpl(presign.uploadUrl, {
      method: presign.method || "PUT",
      headers: { ...presign.headers },
      body: bytes as unknown as BodyInit,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`upload failed: ${res.status} ${text}`);
    }
  }

  /** 轮询至 done/failed */
  async waitParseJob(
    id: string,
    opts: { intervalMs?: number; timeoutMs?: number } = {},
  ): Promise<ParseJobDto> {
    const interval = opts.intervalMs ?? 2000;
    const deadline = Date.now() + (opts.timeoutMs ?? 120000);
    for (;;) {
      const job = await this.getParseJob(id);
      if (job.status === "done" || job.status === "failed") return job;
      if (Date.now() > deadline) throw new Error(`parse job ${id} timeout`);
      await new Promise((r) => setTimeout(r, interval));
    }
  }

  /** PUT 字节到 presign 返回的 uploadUrl（local HMAC / S3 预签名） */
  async uploadBytes(
    presign: { uploadUrl: string; method: string; headers: Record<string, string> },
    bytes: Uint8Array,
  ): Promise<void> {
    const res = await this.fetchImpl(presign.uploadUrl, {
      method: presign.method || "PUT",
      headers: { ...presign.headers },
      body: bytes as unknown as BodyInit,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`upload failed: ${res.status} ${text}`);
    }
  }

  /** 轮询至 done/failed */
  async waitParseJob(
    id: string,
    opts: { intervalMs?: number; timeoutMs?: number } = {},
  ): Promise<ParseJobDto> {
    const interval = opts.intervalMs ?? 2000;
    const deadline = Date.now() + (opts.timeoutMs ?? 120000);
    for (;;) {
      const job = await this.getParseJob(id);
      if (job.status === "done" || job.status === "failed") return job;
      if (Date.now() > deadline) throw new Error(`parse job ${id} timeout`);
      await new Promise((r) => setTimeout(r, interval));
    }
  }

  getParseJob(id: string): Promise<ParseJobDto> {
    return this.request("GET", `/api/v1/parse/jobs/${id}`);
  }

  /** 用完即删：删除云端 PDF 原件 */
  deleteParseSource(id: string): Promise<{ sourceDeleted: boolean }> {
    return this.request("POST", `/api/v1/parse/jobs/${id}/delete-source`, {});
  }

  confirmParse(
    id: string,
    input: {
      items: LabItemDto[];
      date?: string;
      generateSkill?: boolean;
      deleteSource?: boolean;
    },
  ): Promise<{
    labResultId: string;
    sourceDeleted?: boolean;
  }> {
    return this.request("POST", `/api/v1/parse/jobs/${id}/confirm`, {
      deleteSource: true,
      ...input,
    });
  }

  listLabs(patientId?: string): Promise<unknown[]> {
    const q = patientId ? `?patientId=${encodeURIComponent(patientId)}` : "";
    return this.request("GET", `/api/v1/labs${q}`);
  }
}

export function createClient(opts?: ApiClientOptions) {
  return new IbdApiClient(opts);
}
