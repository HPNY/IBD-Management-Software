import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { CreateLabDto, LabService } from "./lab.service";

@ApiTags("lab")
@Controller("labs")
export class LabController {
  constructor(private readonly labs: LabService) {}

  @Get()
  list(@Query("patientId") patientId = "demo") {
    return this.labs.list(patientId);
  }

  @Post()
  create(@Body() dto: CreateLabDto) {
    return this.labs.create(dto);
  }
}
