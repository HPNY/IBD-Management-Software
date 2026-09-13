import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { EnqueueParseInput, ParseService } from "./parse.service";

@ApiTags("parse")
@Controller("parse/jobs")
export class ParseController {
  constructor(private readonly parse: ParseService) {}

  @Post()
  enqueue(@Body() body: EnqueueParseInput) {
    return this.parse.enqueue(body);
  }

  @Get()
  list(@Query("patientId") patientId?: string) {
    return this.parse.list(patientId);
  }

  @Get(":id")
  get(@Param("id") id: string) {
    return this.parse.get(id);
  }
}
