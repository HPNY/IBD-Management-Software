import { Injectable } from "@nestjs/common";

export type ParseJobStatus = "queued" | "running" | "awaiting_review" | "done" | "failed";

export interface ParseJob {
  id: string;
  patientId: string;
  objectKey: string;
  hospitalHint?: string;
  status: ParseJobStatus;
  createdAt: string;
  skillVersionId?: string;
  items?: unknown[];
}

/**
 * MVP 骨架：进程内队列占位。
 * 生产：入 BullMQ `parse` 队列，由 parse-worker 消费。
 */
@Injectable()
export class ParseService {
  private jobs = new Map<string, ParseJob>();

  enqueue(input: {
    patientId: string;
    objectKey: string;
    hospitalHint?: string;
  }): ParseJob {
    const id = `job_${Date.now()}`;
    const job: ParseJob = {
      id,
      patientId: input.patientId,
      objectKey: input.objectKey,
      hospitalHint: input.hospitalHint,
      status: "queued",
      createdAt: new Date().toISOString(),
    };
    this.jobs.set(id, job);
    return job;
  }

  get(id: string): ParseJob | undefined {
    return this.jobs.get(id);
  }

  list(patientId: string): ParseJob[] {
    return [...this.jobs.values()].filter((j) => j.patientId === patientId);
  }
}
