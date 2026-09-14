import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { SyncController } from "./sync.controller";
import { SyncService } from "./sync.service";
import { SyncSnapshotEntity } from "../../database/entities";

@Module({
  imports: [TypeOrmModule.forFeature([SyncSnapshotEntity])],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule {}
