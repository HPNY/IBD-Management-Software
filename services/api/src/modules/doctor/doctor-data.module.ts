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
  LabResultEntity,
  PatientEntity,
  SymptomDiaryEntity,
} from "../../database/entities";
import { RequireScope } from "../../auth/scope.guard";
import type { JwtUser } from "../../auth/types";

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
        ibdType: p?.ibdType ?? null,
      });
    }
    return out;
  }

  /** M3.1/M3.4：详情按 scope 过滤。 */
  async detail(doctorId: string, grantId: string) {
    const g = await this.requireActiveGrant(doctorId, grantId);
    const scope = new Set(g.scope);
    const patient = await this.patients.findOne({ where: { id: g.patientId } });
    const payload: Record<string, unknown> = {
      grantId: g.id,
      scope: g.scope,
      expiresAt: g.expiresAt,
      patient: patient
        ? { id: patient.id, ibdType: patient.ibdType }
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
      const labs = await this.labs.find({
        where: { patientId: g.patientId },
        order: { date: "DESC" },
        take: 3,
      });
      payload["summaryText"] = [
        "病程摘要（自动生成，仅供参考）",
        `检验近 ${labs.length} 次：${labs.map((l) => l.date).join("、") || "无"}`,
        `授权范围：${g.scope.join("/")}`,
      ].join("\n");
    }
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
  detail(@Param("id") id: string, @Req() req: { user?: JwtUser }) {
    return this.data.detail(this.doctorId(req), id);
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
      DoctorNoteEntity,
      DoctorAuditLogEntity,
    ]),
  ],
  controllers: [DoctorDataController, DoctorPatientController],
  providers: [DoctorDataService],
  exports: [DoctorDataService],
})
export class DoctorDataModule {}
