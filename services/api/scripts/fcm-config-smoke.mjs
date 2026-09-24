#!/usr/bin/env node
/** FCM 配置自检：读环境变量，报告 dry-run / 可真发。 */
const path = process.env;
const serverKey = (path.FCM_SERVER_KEY || "").trim();
const projectId = (path.FCM_PROJECT_ID || "").trim();
const clientEmail = (path.FCM_CLIENT_EMAIL || "").trim();
const privateKey = path.FCM_PRIVATE_KEY || "";
const hasServiceAccount = Boolean(projectId && clientEmail && privateKey);
const hasLegacy = Boolean(serverKey);
let mode = "dry-run";
let detail = "未配置任何 FCM_*，服务端将 dry-run";
if (hasServiceAccount) {
  mode = "fcm-v1";
  detail = `服务账号就绪 project=${projectId}`;
} else if (hasLegacy) {
  mode = "fcm-legacy";
  detail = `传统 Server Key 就绪 len=${serverKey.length}`;
} else if (projectId || clientEmail || privateKey || serverKey) {
  mode = "incomplete";
  detail = "FCM_* 填写不完整";
}
console.log(JSON.stringify({ ok: mode.startsWith("fcm"), mode, detail }, null, 2));
process.exit(mode.startsWith("fcm") ? 0 : 1);
