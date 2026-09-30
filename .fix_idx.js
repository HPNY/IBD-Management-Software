const fs=require('fs');const p=process.argv[2];
let t=fs.readFileSync(p,'utf8');
t=t.replace('export { DoctorEntity, DoctorGrantEntity } from "./doctor.entity";',
 'export { DoctorEntity, DoctorGrantEntity } from "./doctor.entity";\nexport type { GrantScopeKey, DoctorReviewStatus } from "./doctor.entity";');
fs.writeFileSync(p,t);
console.log('ok');
