import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { InjectionRecord, InjectionService } from "./injection.service";

@ApiTags("injection")
@Controller("injections")
export class InjectionController {
  constructor(private readonly injections: InjectionService) {}

  @Get()
  list(@Query("patientId") patientId = "demo") {
    return this.injections.list(patientId);
  }

  @Post()
  create(@Body() dto: Omit<InjectionRecord, "id">) {
    return this.injections.create(dto);
  }
}
