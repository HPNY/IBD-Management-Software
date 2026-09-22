import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { DeviceTokenEntity } from "../../database/entities";
import { FcmService } from "./fcm.service";
import { PushController } from "./push.controller";
import { PushService } from "./push.service";

@Module({
  imports: [TypeOrmModule.forFeature([DeviceTokenEntity])],
  controllers: [PushController],
  providers: [PushService, FcmService],
  exports: [PushService, FcmService],
})
export class PushModule {}
