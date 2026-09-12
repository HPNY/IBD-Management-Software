import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { ParseJobEntity } from "../../database/entities";
import { PatientService } from "../patient/patient.service";

@Injectable()
export class ParseService {
  constructor(
    @InjectRepository(ParseJobEntity)
    private readonly jobs: Repository<ParseJobEntity>,
    private readonly patients: PatientService,
  ) {}

  async enqueue(input: {
    patientId?: string;
    objectKey: string;
    hospitalHint?: string;
  }): Promise<ParseJobEntity> {
    const patientId = input.patientId || (await this.patients.ensureDemoPatient()).id;
    return this.jobs.save(
      this.jobs.create({
        patientId,
        objectKey: input.objectKey,
        hospitalHint: input.hospitalHint ?? null,
        status: "queued",
      }),
    );
  }

  async get(id: string): Promise<ParseJobEntity> {
    const job = await this.jobs.findOne({ where: { id } });
    if (!job) throw new NotFoundException(`parse job ${id} not found`);
    return job;
  }

  async list(patientId?: string): Promise<ParseJobEntity[]> {
    const pid = patientId || (await this.patients.ensureDemoPatient()).id;
    return this.jobs.find({
      where: { patientId: pid },
      order: { createdAt: "DESC" },
    });
  }
}
