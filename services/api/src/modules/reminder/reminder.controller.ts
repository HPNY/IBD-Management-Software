import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { CreateReminderDto, ReminderService } from "./reminder.service";

@ApiTags("reminder")
@Controller("reminders")
export class ReminderController {
  constructor(private readonly reminders: ReminderService) {}

  @Get()
  list(@Query("patientId") patientId?: string) {
    return this.reminders.list(patientId);
  }

  @Post()
  create(@Body() dto: CreateReminderDto) {
    return this.reminders.create(dto);
  }
}
