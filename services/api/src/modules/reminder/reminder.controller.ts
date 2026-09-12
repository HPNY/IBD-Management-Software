import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { ReminderRule, ReminderService } from "./reminder.service";

@ApiTags("reminder")
@Controller("reminders")
export class ReminderController {
  constructor(private readonly reminders: ReminderService) {}

  @Get()
  list(@Query("patientId") patientId = "demo") {
    return this.reminders.list(patientId);
  }

  @Post()
  create(@Body() dto: Omit<ReminderRule, "id">) {
    return this.reminders.create(dto);
  }
}
