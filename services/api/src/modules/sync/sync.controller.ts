import { Body, Controller, Delete, Get, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { UseGuards } from "@nestjs/common";
import { CurrentUser } from "../../auth/current-user.decorator";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";
import { PutSnapshotInput, SyncService } from "./sync.service";

@ApiTags("sync")
@ApiBearerAuth()
@Controller("sync")
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  /** 端到端密文写入（scope: full 或 sync_ciphertext） */
  @UseGuards(RequireScope("full", "sync_ciphertext"))
  @Post("ciphertext")
  put(
    @CurrentUser() user: JwtUser,
    @Body()
    body: Omit<PutSnapshotInput, "appUserId"> & { appUserId?: string },
  ) {
    const appUserId = body.appUserId || user.appUserId || user.userId;
    return this.sync.putCipher({ ...body, appUserId });
  }

  @UseGuards(RequireScope("full", "sync_ciphertext"))
  @Get("ciphertexts")
  list(@CurrentUser() user: JwtUser, @Query("appUserId") q?: string) {
    const appUserId = q || user.appUserId || user.userId;
    return this.sync.listCipher(appUserId);
  }

  @UseGuards(RequireScope("full", "sync_ciphertext"))
  @Delete("ciphertexts")
  wipe(@CurrentUser() user: JwtUser, @Query("appUserId") q?: string) {
    const appUserId = q || user.appUserId || user.userId;
    return this.sync.wipe(appUserId);
  }
}
