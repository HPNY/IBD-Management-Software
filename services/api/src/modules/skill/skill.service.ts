import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import {
  ParseSkillEntity,
  ParseSkillVersionEntity,
} from "../../database/entities";

export interface SkillItemRule {
  name: string;
  alias?: string;
  pattern: string;
  multiline?: boolean;
  unit?: string;
  ref_range?: [number, number];
}

export interface SkillContent {
  hospital: string;
  report_type: string;
  version: string;
  date_extraction?: { primary?: string; fallback?: string };
  items: SkillItemRule[];
  special_rules?: unknown[];
  source?: string;
}

export interface ConfirmedLabItem {
  nameNorm: string;
  nameRaw?: string;
  value: number;
  unit?: string;
  refMin?: number;
  refMax?: number;
}

/** 由用户确认的解析结果生成 Skill JSON（规则模板，非可执行代码）。 */
export function buildSkillContent(input: {
  hospital: string;
  reportType: string;
  version: string;
  items: ConfirmedLabItem[];
  reportDate?: string | null;
}): SkillContent {
  const rules: SkillItemRule[] = [];
  for (const it of input.items) {
    const name = (it.nameNorm || it.nameRaw || "").trim();
    if (!name) continue;
    // 项目名后空白 + 数值；兼容中英文名
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    rules.push({
      name,
      alias: it.nameRaw && it.nameRaw !== name ? it.nameRaw : undefined,
      pattern: `${escaped}\\s+([\\d.]+)`,
      multiline: true,
      unit: it.unit ?? undefined,
      ref_range:
        it.refMin != null && it.refMax != null
          ? [it.refMin, it.refMax]
          : undefined,
    });
  }

  const dateExtraction = input.reportDate
    ? {
        primary: input.reportDate.replace(/-/g, "[/-]"),
      }
    : {
        primary: "采集日期:?\\s*(\\d{4})[/-](\\d{1,2})[/-](\\d{1,2})",
      };

  return {
    hospital: input.hospital,
    report_type: input.reportType,
    version: input.version,
    date_extraction: dateExtraction,
    items: rules,
    special_rules: [
      {
        filter: "patient_id_mismatch",
        description: "病案号可能被误匹配为检验值",
        action: "discard",
      },
    ],
    source: "user_confirmed",
  };
}

function nextVersion(current: string | null): string {
  if (!current) return "1.0.0";
  const parts = current.split(".").map((n) => Number(n));
  const major = parts[0] || 1;
  const minor = (parts[1] || 0) + 1;
  const patch = parts[2] || 0;
  return `${major}.${minor}.${patch}`;
}

@Injectable()
export class SkillService {
  private readonly logger = new Logger(SkillService.name);

  constructor(
    @InjectRepository(ParseSkillEntity)
    private readonly skills: Repository<ParseSkillEntity>,
    @InjectRepository(ParseSkillVersionEntity)
    private readonly versions: Repository<ParseSkillVersionEntity>,
  ) {}

  async getActiveSkillContent(
    hospital: string,
    reportType: string,
  ): Promise<SkillContent | null> {
    if (!hospital || !reportType) return null;
    const skill = await this.skills.findOne({
      where: { hospital, reportType },
    });
    if (!skill?.currentVersion) return null;
    const ver = await this.versions.findOne({
      where: { skillId: skill.id, version: skill.currentVersion },
    });
    if (!ver) return null;
    // 异步记 usage
    this.versions
      .increment({ id: ver.id }, "usageCount", 1)
      .catch(() => undefined);
    return ver.content as unknown as SkillContent;
  }

  async listByHospital(hospital?: string) {
    return this.skills.find({
      where: hospital ? { hospital } : {},
      order: { updatedAt: "DESC" },
      take: 100,
    });
  }

  async listVersions(skillId: string) {
    return this.versions.find({
      where: { skillId },
      order: { createdAt: "DESC" },
    });
  }

  /** 确认解析结果 → 新建或升版 Skill。 */
  async upsertFromConfirmed(input: {
    hospital: string;
    reportType: string;
    items: ConfirmedLabItem[];
    reportDate?: string | null;
    userId: string;
  }): Promise<{ skillId: string; versionId: string; version: string; created: boolean }> {
    if (!input.hospital || !input.reportType) {
      throw new NotFoundException("hospital and reportType required to build skill");
    }
    if (!input.items.length) {
      throw new NotFoundException("no confirmed items");
    }

    let skill = await this.skills.findOne({
      where: { hospital: input.hospital, reportType: input.reportType },
    });
    const created = !skill;
    if (!skill) {
      skill = await this.skills.save(
        this.skills.create({
          hospital: input.hospital,
          reportType: input.reportType,
          createdById: input.userId,
          currentVersion: null,
        }),
      );
    }

    const version = nextVersion(skill.currentVersion);
    const content = buildSkillContent({
      hospital: input.hospital,
      reportType: input.reportType,
      version,
      items: input.items,
      reportDate: input.reportDate,
    });

    const ver = await this.versions.save(
      this.versions.create({
        skillId: skill.id,
        version,
        content: content as unknown as Record<string, unknown>,
        source: "user_confirmed",
        createdById: input.userId,
      }),
    );

    await this.skills.save({ ...skill, currentVersion: version });
    this.logger.log(
      `skill ${input.hospital}/${input.reportType} → v${version} items=${input.items.length}`,
    );
    return {
      skillId: skill.id,
      versionId: ver.id,
      version,
      created,
    };
  }
}
