import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { InjectionEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";

export type CreateInjectionDto = Omit<
  InjectionEntity,
  "id" | "patient" | "createdAt" | "updatedAt"
> &
  Partial<Pick<InjectionEntity, "patientId" | "actualDate" | "notes">>;

@Injectable()
export class InjectionService {
  constructor(
    @InjectRepository(InjectionEntity)
    private readonly injections: Repository<InjectionEntity>,
    private readonly patients: PatientService,
  ) {}

  async list(patientId?: string): Promise<InjectionEntity[]> {
    const pid = patientId || (await this.patients.ensureDemoPatient()).id;
    return this.injections.find({
      where: { patientId: pid },
      order: { plannedDate: "ASC" },
    });
  }

  async create(dto: CreateInjectionDto): Promise<InjectionEntity> {
    const patientId = dto.patientId || (await this.patients.ensureDemoPatient()).id;
    const { patient: _p, createdAt: _c, updatedAt: _u, ...rest } = dto as InjectionEntity;
    return this.injections.save(this.injections.create({ ...rest, patientId }));
  }
}
