import { Body, Controller, Post } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { SyncPushItem, SyncService } from "./sync.service";

@ApiTags("sync")
@Controller("sync")
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Post("push")
  push(@Body() body: { items: SyncPushItem[] }) {
    return this.sync.push(body.items ?? []);
  }
}
