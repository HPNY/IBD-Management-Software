import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { QueueEvents } from "bullmq";
import { ParseService, ParseWorkerResult } from "./parse.service";
import { PARSE_QUEUE } from "./parse.module";

/**
 * 监听 Python parse-worker 的完成/失败事件，回写 Postgres。
 * 不在此进程消费任务本身，避免与 Worker 抢队列。
 */
@Injectable()
export class ParseEventsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ParseEventsService.name);
  private events: QueueEvents | null = null;

  constructor(
    private readonly parse: ParseService,
    private readonly config: ConfigService,
  ) {}

  onModuleInit() {
    const url = this.config.get<string>("REDIS_URL") ?? "redis://localhost:6379";
    // 无 Redis 时跳过监听，不影响 API 启动
    if (this.config.get("REDIS_EVENTS") === "off") return;

    try {
      this.events = new QueueEvents(PARSE_QUEUE, {
        connection: { url },
      });

      this.events.on("completed", async ({ jobId, returnvalue }) => {
        try {
          const result =
            typeof returnvalue === "string"
              ? (JSON.parse(returnvalue) as ParseWorkerResult)
              : ((returnvalue ?? {}) as ParseWorkerResult);
          await this.parse.markCompleted(jobId, result);
          this.logger.log(`job ${jobId} done engine=${result.engine ?? "?"}`);
        } catch (err) {
          this.logger.error(
            `failed to persist completed job ${jobId}: ${String(err)}`,
          );
        }
      });

      this.events.on("failed", async ({ jobId, failedReason }) => {
        await this.parse.markFailed(jobId, failedReason || "worker failed");
        this.logger.warn(`job ${jobId} failed: ${failedReason}`);
      });
    } catch (err) {
      this.logger.warn(`QueueEvents disabled: ${String(err)}`);
      this.events = null;
    }
  }

  async onModuleDestroy() {
    if (this.events) await this.events.close();
  }
}
