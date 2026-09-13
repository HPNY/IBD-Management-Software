import { Body, Controller, Post } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { SyncPushItem, SyncService } from "./sync.service";

@ApiTags("sync")
@ApiBearerAuth()
@Controller("sync")
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Post("push")
  push(@CurrentUser() user: JwtUser, @Body() body: { items: SyncPushItem[] }) {
    return this.sync.push(user.userId, body.items ?? []);
  }
}
