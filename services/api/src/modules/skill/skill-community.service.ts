import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import {
  ParseSkillEntity,
  ParseSkillVersionEntity,
  SkillRatingEntity,
} from "../../database/entities";
import { scrubSkillContent } from "./skill-community.scrub";

export interface PublishDto {
  skill: unknown;
  raterHash?: string;
  parentVersion?: string;
}

export interface RateDto {
  skillId: string;
  score: number;
  comment?: string;
  raterHash: string;
  versionId?: string;
}

function nextCollabVersion(current: string | null): string {
  if (!current) return "1.0.0";
  const parts = current.split(".").map((n) => Number(n));
  return `${parts[0] || 1}.${(parts[1] || 0) + 1}.${parts[2] || 0}`;
}

/** T6.1 Skill 社区：匿名发布 / 浏览 / 评分 / 协作升版。 */
@Injectable()
export class SkillCommunityService {
  private readonly logger = new Logger(SkillCommunityService.name);

  constructor(
    @InjectRepository(ParseSkillEntity)
    private readonly skills: Repository<ParseSkillEntity>,
    @InjectRepository(ParseSkillVersionEntity)
    private readonly versions: Repository<ParseSkillVersionEntity>,
    @InjectRepository(SkillRatingEntity)
    private readonly ratings: Repository<SkillRatingEntity>,
  ) {}

  /** C2.1/C2.3：白名单 + 脱敏后发布为 community 版本。 */
  async publish(input: PublishDto) {
    const scrub = scrubSkillContent(input.skill);
    if (!scrub.ok || !scrub.cleaned) {
      throw new BadRequestException({
        message: "skill content rejected",
        errors: scrub.errors,
      });
    }
    const cleaned = scrub.cleaned as {
      hospital: string;
      reportType: string;
      version: string;
      dateExtraction: Record<string, unknown>;
      items: unknown[];
    };

    let skill = await this.skills.findOne({
      where: { hospital: cleaned.hospital, reportType: cleaned.reportType },
    });
    const created = !skill;
    if (!skill) {
      skill = await this.skills.save(
        this.skills.create({
          hospital: cleaned.hospital,
          reportType: cleaned.reportType,
          createdById: input.raterHash ?? null,
          currentVersion: null,
        }),
      );
    }

    const version = nextCollabVersion(skill.currentVersion);
    const content = {
      hospital: cleaned.hospital,
      report_type: cleaned.reportType,
      version,
      date_extraction: cleaned.dateExtraction,
      items: cleaned.items,
      source: "community",
    };

    const ver = await this.versions.save(
      this.versions.create({
        skillId: skill.id,
        version,
        parentVersion: input.parentVersion ?? skill.currentVersion,
        content: content as unknown as Record<string, unknown>,
        source: "community",
        sharedToCommunity: true,
        createdById: input.raterHash ?? null,
      }),
    );
    await this.skills.save({ ...skill, currentVersion: version });
    this.logger.log(
      `community publish ${cleaned.hospital}/${cleaned.reportType} v${version}`,
    );
    return {
      skillId: skill.id,
      versionId: ver.id,
      version,
      parentVersion: ver.parentVersion,
      created,
    };
  }

  /** C3.1：搜索 + 聚合评分。 */
  async search(params: {
    hospital?: string;
    reportType?: string;
    q?: string;
  }) {
    const qb = this.skills.createQueryBuilder("s");
    if (params.hospital) {
      qb.andWhere("s.hospital ILIKE :h", { h: `%${params.hospital}%` });
    }
    if (params.reportType) {
      qb.andWhere("s.reportType ILIKE :t", { t: `%${params.reportType}%` });
    }
    if (params.q) {
      qb.andWhere("(s.hospital ILIKE :q OR s.reportType ILIKE :q)", {
        q: `%${params.q}%`,
      });
    }
    qb.orderBy("s.updatedAt", "DESC").take(50);
    const skills = await qb.getMany();
    return Promise.all(skills.map((s) => this.decorate(s)));
  }

  async getDetail(skillId: string) {
    const skill = await this.skills.findOne({ where: { id: skillId } });
    if (!skill) throw new NotFoundException("skill not found");
    const versions = await this.versions.find({
      where: { skillId },
      order: { createdAt: "DESC" },
    });
    const decorated = await this.decorate(skill);
    return {
      ...decorated,
      versions: versions.map((v) => ({
        id: v.id,
        version: v.version,
        parentVersion: v.parentVersion,
        source: v.source,
        usageCount: v.usageCount,
        sharedToCommunity: v.sharedToCommunity,
        itemCount: Array.isArray((v.content as { items?: unknown[] })?.items)
          ? (v.content as { items: unknown[] }).items.length
          : 0,
      })),
    };
  }

  /** C3.3：取当前版本内容供导入本地 Skill。 */
  async getCurrentContent(skillId: string) {
    const skill = await this.skills.findOne({ where: { id: skillId } });
    if (!skill?.currentVersion) throw new NotFoundException("skill not found");
    const ver = await this.versions.findOne({
      where: { skillId, version: skill.currentVersion },
    });
    if (!ver) throw new NotFoundException("version not found");
    const c = ver.content as Record<string, unknown>;
    return {
      hospital: skill.hospital,
      reportType: skill.reportType,
      version: ver.version,
      dateExtraction: c.date_extraction ?? c.dateExtraction ?? { primary: "" },
      items: c.items ?? [],
      parentVersion: ver.parentVersion,
    };
  }

  /** C3.2：评分 upsert（每人每 skill 一评）。 */
  async rate(input: RateDto) {
    if (!input.skillId || !input.raterHash) {
      throw new BadRequestException("skillId and raterHash required");
    }
    const score = Math.round(input.score);
    if (!(score >= 1 && score <= 5)) {
      throw new BadRequestException("score must be 1-5");
    }
    const skill = await this.skills.findOne({ where: { id: input.skillId } });
    if (!skill) throw new NotFoundException("skill not found");
    if (input.comment && input.comment.length > 500) {
      throw new BadRequestException("comment too long");
    }
    let row = await this.ratings.findOne({
      where: { skillId: input.skillId, raterHash: input.raterHash },
    });
    if (row) {
      row.score = score;
      row.comment = input.comment ?? row.comment;
      row.versionId = input.versionId ?? row.versionId;
    } else {
      row = this.ratings.create({
        skillId: input.skillId,
        versionId: input.versionId ?? null,
        raterHash: input.raterHash,
        score,
        comment: input.comment ?? null,
      });
    }
    await this.ratings.save(row);
    return this.decorate(skill);
  }

  /** C4.1：协作更新 = 提交新内容新版本（仍过脱敏）。 */
  async collaborate(input: {
    skillId: string;
    skill: unknown;
    raterHash?: string;
  }) {
    const skill = await this.skills.findOne({ where: { id: input.skillId } });
    if (!skill) throw new NotFoundException("skill not found");
    const scrub = scrubSkillContent(input.skill);
    if (!scrub.ok || !scrub.cleaned) {
      throw new BadRequestException({
        message: "skill content rejected",
        errors: scrub.errors,
      });
    }
    const cleaned = scrub.cleaned as {
      hospital: string;
      reportType: string;
      dateExtraction: Record<string, unknown>;
      items: unknown[];
    };
    const version = nextCollabVersion(skill.currentVersion);
    const content = {
      hospital: cleaned.hospital,
      report_type: cleaned.reportType,
      version,
      date_extraction: cleaned.dateExtraction,
      items: cleaned.items,
      source: "community",
    };
    const ver = await this.versions.save(
      this.versions.create({
        skillId: skill.id,
        version,
        parentVersion: skill.currentVersion,
        content: content as unknown as Record<string, unknown>,
        source: "community",
        sharedToCommunity: true,
        createdById: input.raterHash ?? null,
      }),
    );
    await this.skills.save({ ...skill, currentVersion: version });
    return {
      skillId: skill.id,
      versionId: ver.id,
      version,
      parentVersion: ver.parentVersion,
    };
  }

  private async decorate(skill: ParseSkillEntity) {
    const agg = await this.ratings
      .createQueryBuilder("r")
      .select("AVG(r.score)", "avg")
      .addSelect("COUNT(*)", "cnt")
      .where("r.skillId = :id", { id: skill.id })
      .getRawOne<{ avg: string | null; cnt: string }>();
    const avg = agg?.avg ? Number(agg.avg) : null;
    const count = Number(agg?.cnt ?? 0);
    const ver = skill.currentVersion
      ? await this.versions.findOne({
          where: { skillId: skill.id, version: skill.currentVersion },
        })
      : null;
    const composite =
      (avg ?? 0) * 20 +
      Math.min(ver?.usageCount ?? 0, 50) +
      Math.min(count * 2, 20);
    return {
      id: skill.id,
      hospital: skill.hospital,
      reportType: skill.reportType,
      currentVersion: skill.currentVersion,
      usageCount: ver?.usageCount ?? 0,
      ratingAvg: avg == null ? null : Math.round(avg * 10) / 10,
      ratingCount: count,
      composite: Math.round(composite * 10) / 10,
    };
  }
}
