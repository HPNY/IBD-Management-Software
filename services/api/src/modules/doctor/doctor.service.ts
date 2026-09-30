import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { InjectRepository } from "@nestjs/typeorm";
import { randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { Repository } from "typeorm";
import {
  DoctorEntity,
  DoctorGrantEntity,
  GrantScopeKey,
  PatientEntity,
} from "../../database/entities";
import type { JwtUser } from "../../auth/types";

export interface DoctorJwt extends JwtUser {
  role?: "doctor";
  doctorId?: string;
}

function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 32).toString("hex");
  return `${salt}:${hash}`;
}

function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(":");
  if (!salt || !hash) return false;
  const a = scryptSync(password, salt, 32);
  const b = Buffer.from(hash, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

const VALID_SCOPES: GrantScopeKey[] = ["labs", "symptoms", "alerts", "summary"];

@Injectable()
export class DoctorAuthService {
  constructor(
    @InjectRepository(DoctorEntity)
    private readonly doctors: Repository<DoctorEntity>,
    private readonly jwt: JwtService,
  ) {}

  /** M1.1：注册（执业证号人工审核占位 → pending）。 */
  async register(input: {
    name: string;
    email: string;
    password: string;
    hospital?: string;
    licenseNo?: string;
  }) {
    if (!input.name?.trim() || !input.email?.trim() || !input.password) {
      throw new BadRequestException("name/email/password required");
    }
    if (input.password.length < 8) {
      throw new BadRequestException("password too short");
    }
    const exists = await this.doctors.findOne({
      where: { email: input.email.trim().toLowerCase() },
    });
    if (exists) throw new BadRequestException("email already registered");
    const doctor = await this.doctors.save(
      this.doctors.create({
        name: input.name.trim().slice(0, 64),
        email: input.email.trim().toLowerCase(),
        passwordHash: hashPassword(input.password),
        hospital: input.hospital?.trim().slice(0, 64) ?? null,
        licenseNo: input.licenseNo?.trim().slice(0, 32) ?? null,
        reviewStatus: "pending",
      }),
    );
    return { id: doctor.id, reviewStatus: doctor.reviewStatus };
  }

  /** 人工审核（开发/运营接口；生产应加管理端鉴权）。 */
  async approve(doctorId: string, status: "approved" | "rejected") {
    const d = await this.doctors.findOne({ where: { id: doctorId } });
    if (!d) throw new NotFoundException("doctor not found");
    d.reviewStatus = status;
    await this.doctors.save(d);
    return { id: d.id, reviewStatus: d.reviewStatus };
  }

  /** M1.1：登录；审核中/拒绝不可用。 */
  async login(email: string, password: string) {
    const d = await this.doctors.findOne({
      where: { email: (email ?? "").trim().toLowerCase() },
    });
    if (!d || !verifyPassword(password ?? "", d.passwordHash)) {
      throw new UnauthorizedException("invalid credentials");
    }
    if (d.reviewStatus !== "approved") {
      throw new ForbiddenException("doctor account not approved yet");
    }
    const accessToken = this.jwt.sign(
      {
        userId: d.id,
        phone: null,
        role: "doctor",
        doctorId: d.id,
        scope: "doctor",
      } as DoctorJwt & { scope: string },
      { expiresIn: "8h" },
    );
    return {
      accessToken,
      doctor: {
        id: d.id,
        name: d.name,
        hospital: d.hospital,
        reviewStatus: d.reviewStatus,
      },
    };
  }

  me(doctorId: string) {
    return this.doctors.findOne({ where: { id: doctorId } });
  }
}

@Injectable()
export class DoctorGrantService {
  constructor(
    @InjectRepository(DoctorGrantEntity)
    private readonly grants: Repository<DoctorGrantEntity>,
    @InjectRepository(PatientEntity)
    private readonly patients: Repository<PatientEntity>,
    @InjectRepository(DoctorEntity)
    private readonly doctors: Repository<DoctorEntity>,
  ) {}

  /** M2.1：生成授权码（范围 + TTL）。 */
  async createCode(input: {
    doctorId: string;
    scope: string[];
    ttlHours?: number;
  }) {
    const doctor = await this.doctors.findOne({
      where: { id: input.doctorId },
    });
    if (!doctor) throw new NotFoundException("doctor not found");
    const scope = (input.scope ?? []).filter((s): s is GrantScopeKey =>
      VALID_SCOPES.includes(s as GrantScopeKey),
    );
    if (scope.length === 0) {
      throw new BadRequestException("scope required");
    }
    const ttlH = Math.min(Math.max(input.ttlHours ?? 24, 1), 24 * 30);
    const code = randomBytes(16).toString("hex");
    const expiresAt = new Date(Date.now() + ttlH * 3600 * 1000);
    const row = await this.grants.save(
      this.grants.create({
        doctorId: input.doctorId,
        patientId: "", // 确认时绑定
        scope,
        code,
        expiresAt,
        confirmed: false,
      }),
    );
    return {
      code: row.code,
      scope: row.scope,
      expiresAt: row.expiresAt,
      // 供前端生成二维码内容
      qrPayload: `ibders-doctor-grant:${row.code}`,
    };
  }

  /** M2.2：患者扫码确认（绑定 patient + 可选 DEK 再包裹）。 */
  async confirm(
    userId: string,
    code: string,
    opts: { wrappedDek?: string; scope?: string[] } = {},
  ) {
    const row = await this.grants.findOne({ where: { code } });
    if (!row) throw new NotFoundException("grant not found");
    if (row.confirmed) {
      // 防劫持：已绑定的码不可被其他患者重复确认
      throw new ForbiddenException("grant already confirmed");
    }
    if (row.revokedAt) throw new ForbiddenException("grant revoked");
    if (row.expiresAt.getTime() < Date.now()) {
      throw new ForbiddenException("grant expired");
    }
    const patient = await this.patients.findOne({ where: { userId } });
    if (!patient) throw new NotFoundException("patient not found");
    // M2.2：未勾选范围不可确认
    const picked = (opts.scope ?? row.scope).filter((s): s is GrantScopeKey =>
      VALID_SCOPES.includes(s as GrantScopeKey),
    );
    if (picked.length === 0) {
      throw new BadRequestException("scope required to confirm");
    }
    row.patientId = patient.id;
    row.scope = picked;
    row.confirmed = true;
    // M2.4：仅存再包裹后的 DEK 密文，不落明文
    if (opts.wrappedDek) {
      if (opts.wrappedDek.length > 8192) {
        throw new BadRequestException("wrappedDek too large");
      }
      row.wrappedDek = opts.wrappedDek;
    }
    await this.grants.save(row);
    return {
      grantId: row.id,
      scope: row.scope,
      expiresAt: row.expiresAt,
      doctorId: row.doctorId,
    };
  }

  /** 患者侧：列表 / 收回 */
  async listForPatient(userId: string) {
    const patient = await this.patients.findOne({ where: { userId } });
    if (!patient) return [];
    const rows = await this.grants.find({
      where: { patientId: patient.id },
      order: { createdAt: "DESC" },
    });
    return rows.map((r) => ({
      id: r.id,
      doctorId: r.doctorId,
      scope: r.scope,
      code: r.code,
      expiresAt: r.expiresAt,
      revokedAt: r.revokedAt,
      confirmed: r.confirmed,
      hasWrappedDek: !!r.wrappedDek,
    }));
  }

  async revoke(userId: string, grantId: string) {
    const patient = await this.patients.findOne({ where: { userId } });
    if (!patient) throw new NotFoundException("patient not found");
    const row = await this.grants.findOne({ where: { id: grantId } });
    if (!row || row.patientId !== patient.id) {
      throw new NotFoundException("grant not found");
    }
    row.revokedAt = new Date();
    await this.grants.save(row);
    return { revoked: true };
  }

  /** 医生侧：有效 Grant 校验（M3 读数据用）。 */
  async requireActive(doctorId: string, grantId: string): Promise<DoctorGrantEntity> {
    const row = await this.grants.findOne({ where: { id: grantId } });
    if (!row || row.doctorId !== doctorId || !row.confirmed) {
      throw new NotFoundException("grant not found");
    }
    if (row.revokedAt || row.expiresAt.getTime() < Date.now()) {
      throw new ForbiddenException("grant inactive");
    }
    return row;
  }
}
