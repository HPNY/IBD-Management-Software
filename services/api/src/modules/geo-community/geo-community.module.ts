import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Injectable,
  Module,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { InjectRepository, TypeOrmModule } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { GeoPostEntity } from "../../database/entities";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";

const BANNED_LOCATION_KEYS = new Set([
  "lat",
  "lng",
  "latitude",
  "longitude",
  "gps",
  "address",
  "location",
  "coords",
]);

/** 稳定伪匿名哈希（非密码学强度，仅避免回传原始 uuid）。 */
export function pseudoHash(id: string): string {
  let h = 2166136261;
  for (var i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}

/** D3.5：禁止精确位置键。 */
export function assertNoPreciseLocation(obj: Record<string, unknown>): void {
  for (const k of Object.keys(obj)) {
    if (BANNED_LOCATION_KEYS.has(k.toLowerCase())) {
      throw new BadRequestException(`forbidden location field: ${k}`);
    }
  }
}

@Injectable()
export class GeoCommunityService {
  constructor(
    @InjectRepository(GeoPostEntity)
    private readonly posts: Repository<GeoPostEntity>,
  ) {}

  async cityCount() {
    const rows = await this.posts
      .createQueryBuilder("p")
      .select("p.city", "city")
      .addSelect("COUNT(DISTINCT p.authorHash)", "members")
      .addSelect("COUNT(*)", "posts")
      .groupBy("p.city")
      .getRawMany<{ city: string; members: string; posts: string }>();
    return rows.map((r) => ({
      city: r.city,
      members: Number(r.members),
      posts: Number(r.posts),
    }));
  }

  async listPosts(city: string) {
    const rows = await this.posts.find({
      where: { city },
      order: { createdAt: "DESC" },
      take: 50,
    });
    // 不回传 authorHash（避免伪匿名 ID 泄露）
    return rows.map((r) => ({
      id: r.id,
      city: r.city,
      nickname: r.nickname,
      content: r.content,
      createdAt: r.createdAt,
    }));
  }

  async createPost(input: {
    city: string;
    nickname: string;
    content: string;
    authorHash: string;
    rawBody?: Record<string, unknown>;
  }) {
    // D3.5：在重组字段前检查客户端原始键，拒绝精确位置
    if (input.rawBody) {
      assertNoPreciseLocation(input.rawBody);
    }
    assertNoPreciseLocation(input as unknown as Record<string, unknown>);
    if (!input.city.trim() || !input.content.trim()) {
      throw new BadRequestException("city and content required");
    }
    if (input.content.length > 500) {
      throw new BadRequestException("content too long");
    }
    return this.posts.save(
      this.posts.create({
        city: input.city.trim().slice(0, 32),
        nickname: (input.nickname || "匿名").trim().slice(0, 32),
        content: input.content.trim().slice(0, 500),
        authorHash: input.authorHash,
      }),
    );
  }

  async deleteOwn(id: string, authorHash: string) {
    const row = await this.posts.findOne({ where: { id } });
    if (!row || row.authorHash !== authorHash) {
      throw new BadRequestException("not found or not owner");
    }
    await this.posts.delete({ id });
    return { deleted: true };
  }
}

@ApiTags("geo-community")
@ApiBearerAuth()
@UseGuards(RequireScope("full", "community", "geo_community"))
@Controller("geo-community")
export class GeoCommunityController {
  constructor(private readonly svc: GeoCommunityService) {}

  private hashOf(req: { user?: JwtUser }): string {
    // 伪匿名：对 appUserId 做稳定短哈希，不存/不回传原始 uuid
    const raw = req.user?.appUserId ?? req.user?.userId ?? "anon";
    return pseudoHash(raw);
  }

  @Get("cities")
  cities() {
    return this.svc.cityCount();
  }

  @Get("posts")
  posts(@Query("city") city?: string) {
    if (!city?.trim()) throw new BadRequestException("city required");
    return this.svc.listPosts(city.trim());
  }

  @Post("posts")
  create(
    @Body() body: Record<string, unknown>,
    @Req() req: { user?: JwtUser },
  ) {
    return this.svc.createPost({
      city: String(body.city ?? ""),
      nickname: body.nickname != null ? String(body.nickname) : "匿名",
      content: String(body.content ?? ""),
      authorHash: this.hashOf(req),
      rawBody: body,
    });
  }

  @Delete("posts/:id")
  remove(@Param("id") id: string, @Req() req: { user?: JwtUser }) {
    return this.svc.deleteOwn(id, this.hashOf(req));
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([GeoPostEntity])],
  controllers: [GeoCommunityController],
  providers: [GeoCommunityService],
  exports: [GeoCommunityService],
})
export class GeoCommunityModule {}
