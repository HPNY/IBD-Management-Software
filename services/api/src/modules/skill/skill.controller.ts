import { Controller, Get, Param, Query } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { SkillService } from "./skill.service";

@ApiTags("skills")
@ApiBearerAuth()
@Controller("skills")
export class SkillController {
  constructor(private readonly skills: SkillService) {}

  @Get()
  list(@Query("hospital") hospital?: string) {
    return this.skills.listByHospital(hospital);
  }

  @Get(":id/versions")
  versions(@Param("id") id: string) {
    return this.skills.listVersions(id);
  }
}
