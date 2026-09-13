import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../auth/current-user.decorator";
import type { JwtUser } from "../../auth/types";
import { CreateReminderDto, ReminderService } from "./reminder.service";

@ApiTags("reminder")
@ApiBearerAuth()
@Controller("reminders")
export class ReminderController {
  constructor(private readonly reminders: ReminderService) {}

  @Get()
  list(@CurrentUser() user: JwtUser, @Query("patientId") patientId?: string) {
    return this.reminders.list(user.userId, patientId);
  }

  @Post()
  create(@CurrentUser() user: JwtUser, @Body() dto: CreateReminderDto) {
    return this.reminders.create(user.userId, dto);
  }
}
