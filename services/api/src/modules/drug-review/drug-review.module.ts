import {
  Body,
  Controller,
  Get,
  Injectable,
  Module,
  BadRequestException,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { InjectRepository, TypeOrmModule } from "@nestjs/typeorm";
import { createHash } from "node:crypto";
import { Repository } from "typeorm";
import {
  DrugReviewSubmissionEntity,
} from "../../database/entities";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";

export interface DrugReviewUpload {
  drugName: string;
  ibdType?: string;
  efficacy: number;
  seSideEffect: number;
  sideEffectTypes?: string[];
  stillUsing?: boolean;
  comment?: string;
}

const ALLOWED = new Set([
  "drugName",
  "ibdType",
  "efficacy",
  "seSideEffect",
  "sideEffectTypes",
  "stillUsing",
  "comment",
]);

/** D2.5：白名单校验。 */
export function assertDrugReviewPayload(raw: unknown): DrugReviewUpload {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new BadRequestException("payload must be object");
  }
  const src = raw as Record<string, unknown>;
  for (const k of Object.keys(src)) {
    if (!ALLOWED.has(k)) {
      throw new BadRequestException(`forbidden field: ${k}`);
    }
  }
  const drugName = String(src.drugName ?? "").trim();
  if (!drugName) throw new BadRequestException("drugName required");
  const efficacy = Number(src.efficacy);
  const se = Number(src.seSideEffect);
  if (!(efficacy >= 1 && efficacy <= 5)) {
    throw new BadRequestException("efficacy 1-5");
  }
  if (!(se >= 0 && se <= 3)) {
    throw new BadRequestException("seSideEffect 0-3");
  }
  const comment =
    typeof src.comment === "string" && src.comment.trim()
      ? src.comment.trim().slice(0, 500)
      : undefined;
  return {
    drugName,
    ibdType: typeof src.ibdType === "string" ? src.ibdType.slice(0, 8) : "unknown",
    efficacy: Math.round(efficacy),
    seSideEffect: Math.round(se),
    sideEffectTypes: Array.isArray(src.sideEffectTypes)
      ? src.sideEffectTypes.map((x) => String(x).slice(0, 32))
      : [],
    stillUsing: src.stillUsing !== false,
    comment,
  };
}

@Injectable()
export class DrugReviewService {
  constructor(
    @InjectRepository(DrugReviewSubmissionEntity)
    private readonly reviews: Repository<DrugReviewSubmissionEntity>,
  ) {}

  async submit(input: DrugReviewUpload, raterHash: string) {
    let row = await this.reviews.findOne({
      where: { drugName: input.drugName, raterHash },
    });
    if (row) {
      Object.assign(row, {
        ibdType: input.ibdType,
        efficacy: input.efficacy,
        seSideEffect: input.seSideEffect,
        sideEffectTypes: input.sideEffectTypes,
        stillUsing: input.stillUsing,
        comment: input.comment,
      });
    } else {
      row = this.reviews.create({
        ...input,
        raterHash,
      });
    }
    return this.reviews.save(row);
  }

  async summary(drug: string, ibdType?: string) {
    const qb = this.reviews
      .createQueryBuilder("r")
      .where("r.drugName ILIKE :d", { d: `%${drug}%` });
    if (ibdType) qb.andWhere("r.ibdType = :t", { t: ibdType });
    const rows = await qb.getMany();
    const n = rows.length;
    const avg = n === 0 ? 0 : rows.reduce((a, b) => a + b.efficacy, 0) / n;
    const se = [0, 0, 0, 0];
    const typeCount = new Map<string, number>();
    for (const r of rows) {
      se[r.seSideEffect] = (se[r.seSideEffect] ?? 0) + 1;
      for (const t of r.sideEffectTypes ?? []) {
        typeCount.set(t, (typeCount.get(t) ?? 0) + 1);
      }
    }
    return {
      drugName: drug,
      count: n,
      avgEfficacy: Math.round(avg * 10) / 10,
      seDist: se,
      sideEffectTypes: [...typeCount.entries()]
        .map(([type, count]) => ({ type, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 8),
    };
  }
}

@ApiTags("drug-reviews")
@ApiBearerAuth()
@UseGuards(RequireScope("full", "community", "drug_review"))
@Controller("drug-reviews")
export class DrugReviewController {
  constructor(private readonly svc: DrugReviewService) {}

  private hashOf(req: { user?: JwtUser }): string {
    const raw = req.user?.appUserId ?? req.user?.userId ?? "anon";
    return createHash("sha256").update(raw).digest("hex").slice(0, 16);
  }

  @Post()
  submit(@Body() body: unknown, @Req() req: { user?: JwtUser }) {
    const dto = assertDrugReviewPayload(body);
    return this.svc.submit(dto, this.hashOf(req));
  }

  @Get("summary")
  summary(@Query("drug") drug?: string, @Query("ibdType") ibdType?: string) {
    if (!drug || !drug.trim()) {
      throw new BadRequestException("drug query required");
    }
    return this.svc.summary(drug.trim(), ibdType);
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([DrugReviewSubmissionEntity])],
  controllers: [DrugReviewController],
  providers: [DrugReviewService],
  exports: [DrugReviewService],
})
export class DrugReviewModule {}