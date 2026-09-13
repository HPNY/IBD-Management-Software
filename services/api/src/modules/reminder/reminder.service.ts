import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { InjectionEntity, ReminderRuleEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";

export type CreateReminderDto = Omit<
  ReminderRuleEntity,
  "id" | "patient" | "createdAt" | "updatedAt"
> &
  Partial<Pick<ReminderRuleEntity, "patientId" | "enabled">>;

export interface DueReminder {
  kind: "injection" | "medication" | "followup";
  injectionId?: string;
  drug?: string;
  plannedDate: string;
  daysUntil: number;
  leadDays: number;
  message: string;
  route?: string;
  dose?: string;
  phase?: string;
}

@Injectable()
export class ReminderService {
  constructor(
    @InjectRepository(ReminderRuleEntity)
    private readonly rules: Repository<ReminderRuleEntity>,
    @InjectRepository(InjectionEntity)
    private readonly injections: Repository<InjectionEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(userId: string, patientId?: string): Promise<ReminderRuleEntity[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    return this.rules.find({ where: { patientId: pid } });
  }

  async create(userId: string, dto: CreateReminderDto): Promise<ReminderRuleEntity> {
    const patientId =
      dto.patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const { patient: _p, createdAt: _c, updatedAt: _u, ...rest } =
      dto as ReminderRuleEntity;
    return this.rules.save(
      this.rules.create({ ...rest, patientId, enabled: dto.enabled ?? true }),
    );
  }

  /**
   * 计算到期提醒：默认注射前 leadDays 天（规则缺失则 3 天）。
   * 客户端拉取后做本地通知；也可被定时任务写入推送队列。
   */
  async due(userId: string, patientId?: string): Promise<DueReminder[]> {
    const pid = patientId || (await this.patients.ensurePatientForUser(userId)).id;
    const rules = await this.rules.find({ where: { patientId: pid } });
    const injRule = rules.find((r) => r.kind === "injection" && r.enabled !== false);
    const leadDays = injRule?.leadDays ?? 3;

    const today = new Date().toISOString().slice(0, 10);
    const windowEnd = new Date(Date.now() + leadDays * 86400000)
      .toISOString()
      .slice(0, 10);

    // 含已逾期（plannedDate < today 且未打）与未来 leadDays 窗口
    const rows = await this.injections
      .createQueryBuilder("i")
      .where("i.patientId = :pid", { pid })
      .andWhere("i.actualDate IS NULL")
      .andWhere("i.plannedDate <= :windowEnd", { windowEnd })
      .orderBy("i.plannedDate", "ASC")
      .getMany();

    return rows.map((r) => {
      const daysUntil = Math.round(
        (new Date(`${r.plannedDate}T00:00:00Z`).getTime() -
          new Date(`${today}T00:00:00Z`).getTime()) /
          86400000,
      );
      const overdue = daysUntil < 0;
      return {
        kind: "injection" as const,
        injectionId: r.id,
        drug: r.drug,
        plannedDate: r.plannedDate,
        daysUntil,
        leadDays,
        route: r.route,
        dose: r.dose,
        phase: r.phase,
        message: overdue
          ? `${r.drug} 已逾期 ${-daysUntil} 天，请尽快补种（计划 ${r.plannedDate}）`
          : daysUntil === 0
            ? `今天需注射 ${r.drug}（${r.dose}，${r.route === "sc" ? "皮下" : "静脉"}）`
            : `还有 ${daysUntil} 天需注射 ${r.drug}（${r.dose}）`,
      };
    });
  }
}
