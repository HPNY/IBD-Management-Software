const fs = require('fs');
const path = require('path');
const root = process.argv[2];
// entities index
let idx = fs.readFileSync(path.join(root,'services/api/src/database/entities/index.ts'),'utf8');
if (!idx.includes('DoctorEntity')) {
  idx = idx.replace('export { DeviceTokenEntity } from "./device-token.entity";',
    'export { DeviceTokenEntity } from "./device-token.entity";\nexport { DoctorEntity, DoctorGrantEntity } from "./doctor.entity";');
  idx = idx.replace('import { DeviceTokenEntity } from "./device-token.entity";',
    'import { DeviceTokenEntity } from "./device-token.entity";\nimport { DoctorEntity, DoctorGrantEntity } from "./doctor.entity";');
  idx = idx.replace('DeviceTokenEntity,','DeviceTokenEntity,\n  DoctorEntity,\n  DoctorGrantEntity,');
}
fs.writeFileSync(path.join(root,'services/api/src/database/entities/index.ts'), idx);
// app.module
let app = fs.readFileSync(path.join(root,'services/api/src/app.module.ts'),'utf8');
if (!app.includes('DoctorModule')) {
  app = app.replace('import { GeoCommunityModule } from "./modules/geo-community/geo-community.module";',
    'import { GeoCommunityModule } from "./modules/geo-community/geo-community.module";\nimport { DoctorModule } from "./modules/doctor/doctor.module";');
  app = app.replace('GeoCommunityModule,','GeoCommunityModule,\n    DoctorModule,');
}
fs.writeFileSync(path.join(root,'services/api/src/app.module.ts'), app);
// auth types scope
let types = fs.readFileSync(path.join(root,'services/api/src/auth/types.ts'),'utf8');
if (!types.includes('"doctor"')) {
  types = types.replace('| "geo_community";','| "geo_community"\n    | "doctor"\n    | "doctor_grant";');
}
fs.writeFileSync(path.join(root,'services/api/src/auth/types.ts'), types);
console.log('wired');
