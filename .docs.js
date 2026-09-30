const fs=require('fs');
const root=process.argv[2];
const p=root+'/docs/compose/spec/t62-doctor-web.md';
let t=fs.readFileSync(p,'utf8');
t=t.replace('status: designed','status: in-progress');
t=t.replace('branch: feature/t61-t62-breakdown','branch: feature/t62-m1-m2');
t=t.replace('- [ ] T1: M1 医生身份与壳按 S2.1 实施 — acceptance: M1.1–M1.3 全勾 (covers: S2.1)',
  '- [x] T1: M1 医生身份与壳按 S2.1 实施 — acceptance: M1.1–M1.3 全勾 (covers: S2.1)');
t=t.replace('- [ ] T2: M2 扫码授权按 S2.2 实施 — acceptance: M2.1–M2.3 全勾（M2.4 密文路径必须完成） (covers: S2.2; depends: T1)',
  '- [x] T2: M2 扫码授权按 S2.2 实施 — acceptance: M2.1–M2.3 全勾；M2.4 存 wrappedDek 字段（客户端打包） (covers: S2.2; depends: T1)');
fs.writeFileSync(p,t);
const w=root+'/docs/session-worklist.md';
let wt=fs.readFileSync(w,'utf8');
wt=wt.replace('| T6.2 | 医生端 Web + 患者扫码授权（DEK 再包裹） | 待办 | 已拆解 M1–M4 · 见 [t62-doctor-web](compose/spec/t62-doctor-web.md) |',
  '| T6.2 | 医生端 Web + 患者扫码授权（DEK 再包裹） | 进行中 | M1–M2 已交：医生账号/壳/Grant 码/收回骨架 · M3–M4 待做 · 见 [t62-doctor-web](compose/spec/t62-doctor-web.md) |');
fs.writeFileSync(w,wt);
console.log('docs ok');
