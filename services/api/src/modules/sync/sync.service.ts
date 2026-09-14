import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { SyncSnapshotEntity } from "../../database/entities";

export interface PutSnapshotInput {
  appUserId: string;
  dataType: string;
  cipher: string;
  nonce: string;
  clientUpdatedAt: string;
  /** 本地 version，冲突时取较大者 */
  version?: number;
}

@Injectable()
export class SyncService {
  constructor(
    @InjectRepository(SyncSnapshotEntity)
    private readonly snaps: Repository<SyncSnapshotEntity>,
  ) {}

  /** 上传端到端密文（服务端不解密）。 */
  async putCipher(input: PutSnapshotInput) {
    if (!input.appUserId || !input.dataType || !input.cipher || !input.nonce) {
      throw new NotFoundException("appUserId/dataType/cipher/nonce required");
    }
    const existing = await this.snaps.findOne({
      where: { appUserId: input.appUserId, dataType: input.dataType },
    });
    const version = String(input.version ?? Date.now());
    if (existing) {
      // 仅当客户端 version 更大才覆盖
      if (Number(version) <= Number(existing.version)) {
        return {
          id: existing.id,
          version: existing.version,
          skipped: true,
        };
      }
      return this.snaps.save({
        ...existing,
        cipher: input.cipher,
        nonce: input.nonce,
        version,
        clientUpdatedAt: new Date(input.clientUpdatedAt),
      });
    }
    return this.snaps.save(
      this.snaps.create({
        appUserId: input.appUserId,
        dataType: input.dataType,
        cipher: input.cipher,
        nonce: input.nonce,
        version,
        clientUpdatedAt: new Date(input.clientUpdatedAt),
      }),
    );
  }

  async listCipher(appUserId: string) {
    return this.snaps.find({
      where: { appUserId },
      order: { dataType: "ASC" },
    });
  }

  /** 用户要求删除云端副本。 */
  async wipe(appUserId: string) {
    const res = await this.snaps.delete({ appUserId });
    return { deleted: res.affected ?? 0 };
  }
}
