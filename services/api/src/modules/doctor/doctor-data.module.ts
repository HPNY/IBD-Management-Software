import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { InjectRepository, TypeOrmModule } from "@nestjs/typeorm";
import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  Repository,
} from "typeorm";
import {
  DoctorGrantEntity,
  InjectionEntity,
  LabResultEntity,
  MedicationEntity,
  PatientEntity,
  SymptomDiaryEntity,
} from "../../database/entities";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";
import { buildVisitSummaryText } from "./visit-summary";

@Entity("doctor_notes")
export class DoctorNoteEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  grantId: string;

  @Column({ type: "uuid" })
  doctorId: string;

  @Column({ type: "uuid" })
  patientId: string;

  @Column({ type: "varchar", length: 10, nullable: true })
  anchorDate: string | null;

  @Column({ type: "varchar", length: 500 })
  content: string;

  @CreateDateColumn()
  createdAt: Date;
}

@Entity("doctor_audit_logs")
export class DoctorAuditLogEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ type: "uuid" })
  doctorId: string;

  @Column({ type: "uuid" })
  patientId: string;

  @Column({ type: "varchar", length: 32 })
  action: string;

  @Column({ type: "varchar", length: 64, nullable: true })
  resourceId: string | null;

  @CreateDateColumn()
  createdAt: Date;
}

/** M3.4：require 字段是否在授权 scope 内。 */
export function scopeAllows(granted: string[], require?: string): boolean {
  if (!require) return true;
  return granted.includes(require);
}

@Injectable()
export class DoctorDataService {
  constructor(
    @InjectRepository(DoctorGrantEntity)
    private readonly grants: Repository<DoctorGrantEntity>,
    @InjectRepository(PatientEntity)
    private readonly patients: Repository<PatientEntity>,
    @InjectRepository(LabResultEntity)
    private readonly labs: Repository<LabResultEntity>,
    @InjectRepository(SymptomDiaryEntity)
    private readonly diaries: Repository<SymptomDiaryEntity>,
    @InjectRepository(MedicationEntity)
    private readonly meds: Repository<MedicationEntity>,
    @InjectRepository(InjectionEntity)
    private readonly injections: Repository<InjectionEntity>,
    @InjectRepository(DoctorNoteEntity)
    private readonly notes: Repository<DoctorNoteEntity>,
    @InjectRepository(DoctorAuditLogEntity)
    private readonly audits: Repository<DoctorAuditLogEntity>,
  ) {}

  private async requireActiveGrant(doctorId: string, grantId: string) {
    const g = await this.grants.findOne({ where: { id: grantId } });
    if (!g || g.doctorId !== doctorId || !g.confirmed) {
      throw new NotFoundException("grant not found");
    }
    if (g.revokedAt || g.expiresAt.getTime() < Date.now()) {
      throw new ForbiddenException("grant inactive");
    }
    return g;
  }

  private async audit(
    doctorId: string,
    patientId: string,
    action: string,
    resourceId?: string,
  ) {
    await this.audits.save(
      this.audits.create({
        doctorId,
        patientId,
        action,
        resourceId: resourceId ?? null,
      }),
    );
  }

  /** M3.1：已授权患者列表。 */
  async listPatients(doctorId: string) {
    const rows = await this.grants.find({
      where: { doctorId, confirmed: true },
      order: { createdAt: "DESC" },
    });
    const out = [];
    for (const g of rows) {
      if (g.revokedAt || g.expiresAt.getTime() < Date.now()) continue;
      const p = await this.patients.findOne({ where: { id: g.patientId } });
      out.push({
        grantId: g.id,
        patientId: g.patientId,
        scope: g.scope,
        expiresAt: g.expiresAt,
        // 诊断类型仅在 summary 授权时展示
        ...(g.scope.includes("summary")
          ? { ibdType: p?.ibdType ?? null }
          : {}),
      });
    }
    return out;
  }

  /** M3.1/M3.4：详情按 scope 过滤；require 字段不在授权内则 403。 */
  async detail(doctorId: string, grantId: string, require?: string) {
    const g = await this.requireActiveGrant(doctorId, grantId);
    const scope = new Set(g.scope);
    if (!scopeAllows(g.scope, require)) {
      throw new ForbiddenException(`scope ${require} not granted`);
    }
    const patient = await this.patients.findOne({ where: { id: g.patientId } });
    const payload: Record<string, unknown> = {
      grantId: g.id,
      scope: g.scope,
      expiresAt: g.expiresAt,
      // ibdType 仅在 summary 范围披露，避免越权泄露诊断
      patient: patient
        ? {
            id: patient.id,
            ...(scope.has("summary") ? { ibdType: patient.ibdType } : {}),
          }
        : null,
    };
    if (scope.has("labs")) {
      payload["labs"] = await this.labs.find({
        where: { patientId: g.patientId },
        order: { date: "DESC" },
        take: 50,
      });
    }
    if (scope.has("symptoms")) {
      payload["symptoms"] = await this.diaries.find({
        where: { patientId: g.patientId },
        order: { date: "DESC" },
        take: 60,
      });
    }
    if (scope.has("alerts")) {
      // 简单规则：最近便血/剧痛计数（复用日记）
      const recent = await this.diaries.find({
        where: { patientId: g.patientId },
        order: { date: "DESC" },
        take: 7,
      });
      const blood = recent.filter(
        (d) => d.bloodyStool === "trace" || d.bloodyStool === "obvious",
      ).length;
      payload["alerts"] = {
        recentBloodDays: blood,
        note: blood > 0 ? "近 7 日出现便血记录" : "近 7 日未见便血",
      };
    }
    if (scope.has("summary")) {
      const labRows = await this.labs.find({
        where: { patientId: g.patientId },
        order: { date: "DESC" },
        take: 5,
      });
      const diaryRows = await this.diaries.find({
        where: { patientId: g.patientId },
        order: { date: "DESC" },
        take: 7,
      });
      const medRows = await this.meds.find({
        where: { patientId: g.patientId },
        order: { startDate: "DESC" },
        take: 10,
      });
      const injRows = await this.injections.find({
        where: { patientId: g.patientId },
        order: { plannedDate: "DESC" },
        take: 5,
      });
      const summaryText = buildVisitSummaryText({
        meds: medRows.map((m) => ({
          drugName: m.drugName,
          dosage: m.dosage,
          frequency: m.frequency,
          status: m.status,
        })),
        labs: labRows.map((l) => ({
          date: l.date,
          items: (l.items ?? []).map((i) => ({
            nameNorm: i.nameNorm,
            value: i.value,
            unit: i.unit,
          })),
        })),
        injections: injRows.map((i) => ({
          drug: i.drug,
          plannedDate: i.plannedDate,
          dose: i.dose,
        })),
        symptoms: diaryRows.map((d) => {
          const raw = d as unknown as Record<string, unknown>;
          return {
            date: d.date,
            painLevel: d.painLevel,
            diarrheaCount: d.diarrheaCount,
            bowelCount: (raw["bowelCount"] ?? raw["bowel_count"]) as number | null,
            stoolType: d.stoolType,
            bloodyStool: d.bloodyStool,
            urgency: (raw["urgency"] ?? 0) as number | boolean | null,
            mucus: (raw["mucus"] ?? 0) as number | boolean | null,
          };
        }),
        ibdType: patient?.ibdType ?? null,
      });
      payload["summaryText"] = summaryText;
      payload["ibdType"] = patient?.ibdType ?? null;
    }
    // M3.3：医生可见本人写过的建议
    payload["notes"] = await this.notes.find({
      where: { grantId: g.id },
      order: { createdAt: "DESC" },
    });
    await this.audit(doctorId, g.patientId, "view", g.id);
    return payload;
  }

  /** M3.3：医学建议。 */
  async addNote(
    doctorId: string,
    grantId: string,
    content: string,
    anchorDate?: string,
  ) {
    const g = await this.requireActiveGrant(doctorId, grantId);
    if (!content?.trim()) throw new BadRequestException("content required");
    const note = await this.notes.save(
      this.notes.create({
        grantId: g.id,
        doctorId,
        patientId: g.patientId,
        anchorDate: anchorDate ?? null,
        content: content.trim().slice(0, 500),
      }),
    );
    await this.audit(doctorId, g.patientId, "note", note.id);
    return note;
  }

  async listNotesForGrant(doctorId: string, grantId: string) {
    const g = await this.requireActiveGrant(doctorId, grantId);
    return this.notes.find({
      where: { grantId: g.id },
      order: { createdAt: "DESC" },
    });
  }

  /** M3.3：患者侧看建议（by patientId）。 */
  async listNotesForPatient(userId: string) {
    // patientId == userId mapping via patients table is by userId; notes store patientId
    const p = await this.patients.findOne({ where: { userId } });
    if (!p) return [];
    return this.notes.find({
      where: { patientId: p.id },
      order: { createdAt: "DESC" },
    });
  }

  /** M4.1：患者审计列表。 */
  async listAuditsForPatient(userId: string) {
    const p = await this.patients.findOne({ where: { userId } });
    if (!p) return [];
    return this.audits.find({
      where: { patientId: p.id },
      order: { createdAt: "DESC" },
      take: 100,
    });
  }
}

@ApiTags("doctor-data")
@ApiBearerAuth()
@UseGuards(RequireScope("doctor"))
@Controller("doctor-data")
export class DoctorDataController {
  constructor(private readonly data: DoctorDataService) {}

  private doctorId(req: { user?: JwtUser }): string {
    const u = req.user as { doctorId?: string; userId?: string };
    return u?.doctorId ?? u?.userId ?? "";
  }

  @Get("patients")
  patients(@Req() req: { user?: JwtUser }) {
    return this.data.listPatients(this.doctorId(req));
  }

  @Get("grants/:id")
  detail(
    @Param("id") id: string,
    @Req() req: { user?: JwtUser },
    @Query("require") require?: string,
  ) {
    return this.data.detail(this.doctorId(req), id, require);
  }

  @Post("grants/:id/notes")
  addNote(
    @Param("id") id: string,
    @Body() body: { content: string; anchorDate?: string },
    @Req() req: { user?: JwtUser },
  ) {
    return this.data.addNote(
      this.doctorId(req),
      id,
      body.content,
      body.anchorDate,
    );
  }

  @Get("grants/:id/notes")
  listNotes(@Param("id") id: string, @Req() req: { user?: JwtUser }) {
    return this.data.listNotesForGrant(this.doctorId(req), id);
  }
}

@ApiTags("doctor-patient")
@ApiBearerAuth()
@UseGuards(RequireScope("full", "doctor_grant"))
@Controller("doctor-patient")
export class DoctorPatientController {
  constructor(private readonly data: DoctorDataService) {}

  @Get("notes")
  myNotes(@Req() req: { user?: JwtUser }) {
    return this.data.listNotesForPatient(req.user?.userId ?? "");
  }

  @Get("audits")
  myAudits(@Req() req: { user?: JwtUser }) {
    return this.data.listAuditsForPatient(req.user?.userId ?? "");
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([
      DoctorGrantEntity,
      PatientEntity,
      LabResultEntity,
      SymptomDiaryEntity,
      MedicationEntity,
      InjectionEntity,
      DoctorNoteEntity,
      DoctorAuditLogEntity,
    ]),
  ],
  controllers: [DoctorDataController, DoctorPatientController],
  providers: [DoctorDataService],
  exports: [DoctorDataService],
})
export class DoctorDataModule {}
