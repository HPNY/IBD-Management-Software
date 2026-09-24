import { BadRequestException, Body, Controller, Delete, ForbiddenException, Get, Headers, Post, Put, Query, RawBodyRequest, Req, UseGuards } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import type { Request } from "express";
import { Public } from "../auth/public.decorator";
import { RequireScope } from "../auth/scope.guard";
import { StorageService } from "./storage.service";

@ApiTags("files")
@Controller("files")
export class FilesController {
  constructor(private readonly storage: StorageService) {}

  /** 生成直传预签名（需登录或 parse_session） */
  @UseGuards(RequireScope("full", "parse_session"))
  @Post("presign")
  async presign(
    @Body()
    body: {
      filename: string;
      contentType?: string;
      patientId?: string;
      expiresInSec?: number;
    },
  ) {
    if (!body?.filename) throw new BadRequestException("filename required");
    return this.storage.presign(body);
  }

  /** 仅 local driver：HMAC 签名校验，免 JWT */
  @Public()
  @Put("upload")
  async upload(
    @Query("objectKey") objectKey: string,
    @Query("expires") expiresQ: string,
    @Query("sig") sig: string,
    @Req() req: RawBodyRequest<Request>,
    @Headers("content-type") contentType: string | undefined,
  ) {
    if (this.storage.driver !== "local") {
      throw new BadRequestException("use S3 presigned URL, not API upload");
    }
    if (!objectKey) throw new BadRequestException("objectKey required");
    const expires = Number(expiresQ ?? 0);
    if (!expires || !sig) {
      throw new BadRequestException("missing expires/sig");
    }
    if (!this.storage.verifyLocalSignature(objectKey, expires, sig)) {
      throw new ForbiddenException("invalid or expired signature");
    }
    const body = req.rawBody ?? (await this.readRaw(req));
    if (!body || body.length === 0) {
      throw new BadRequestException("empty body");
    }
    this.storage.putLocal(objectKey, body, contentType);
    return { ok: true, objectKey, size: body.length };
  }

  @Get("meta")
  async meta(@Query("objectKey") objectKey: string) {
    if (!objectKey) throw new BadRequestException("objectKey required");
    try {
      const obj = await this.storage.get(objectKey);
      return { objectKey, size: obj.size, contentType: obj.contentType ?? null };
    } catch {
      return { objectKey, exists: false };
    }
  }

  /** 用完即删：删除已上传原件（仅限 parse/:id/delete-source 调用链；此处拒绝裸 objectKey 删除） */
  @UseGuards(RequireScope("full", "parse_session"))
  @Delete("object")
  async deleteObject(@Query("objectKey") objectKey: string) {
    if (!objectKey) throw new BadRequestException("objectKey required");
    // 防 IDOR：objectKey 任意删除会清掉他人文件。
    // 请走 POST /parse/jobs/:id/delete-source（带患者归属校验）。
    throw new ForbiddenException(
      "use POST /parse/jobs/:id/delete-source (ownership-checked)",
    );
  }

  private readRaw(req: Request): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const chunks: Buffer[] = [];
      req.on("data", (c: Buffer) => chunks.push(c));
      req.on("end", () => resolve(Buffer.concat(chunks)));
      req.on("error", reject);
    });
  }
}
