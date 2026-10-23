# IBDers

**English** | [简体中文](README.zh-CN.md)

A full-disease-course self-management app for IBD (Crohn's disease / ulcerative colitis) patients.

**Version**: [v0.1.0](https://github.com/HPNY/IBD-Management-Software/releases/tag/v0.1.0) · **CI**: smoke/E2E green on `main` (not device-verified)

**Design principle: medical data stays on your own phone by default; nothing is uploaded to a server without explicit consent.**

| Document | Description |
|------|------|
| [PRD](docs/IBD-Disease-Course-Management-PRD.md) | Product requirements ([中文](docs/IBD病程管理程序PRD.md)) |
| [Architecture analysis](docs/compose/spec/architecture-techstack.md) | Tech stack & system design |
| [Local-first rework](docs/compose/spec/local-first.md) | Privacy architecture & phasing |
| [Push privacy boundary](docs/push-privacy.md) | Local notify baseline · remote opt-in · payload allowlist |
| [Device test checklist](docs/device-test-checklist.md) | AVD / real-device acceptance |
| [Config hardening checklist](docs/config-hardening-checklist.md) | Env, secrets, deps, CI |
| [Configuration](docs/configuration.md) | All env vars & `STORAGE_LOCAL_DIR` |
| [Session worklist](docs/session-worklist.md) | Open backlog · mandatory status sync |

---

## Architecture at a glance

```text
┌─────────────────────────────────────────────────────┐
│  Flutter App (personal terminal)                     │
│  · app_user_uuid (locally generated, no forced login) │
│  · SQLCipher-encrypted local DB (Keystore key)        │
│  · All course data read/written locally; injections   │
│    use local notifications                            │
└───────────────┬─────────────────────────────────────┘
                │ only with explicit user consent
                ▼
     ┌──────────────────────────────┐
     │  Optional cloud capabilities  │
     │  ① one-shot PDF parse-session │
     │  ② E2E ciphertext backup/sync │
     │  ③ Skill templates (no PHI)   │
     │  ④ system push (opt-in ·      │
     │     generic copy)             │
     └──────────────────────────────┘
```

| Mode | Behavior |
|------|----------|
| Default | Course data stays local; no account, no upload |
| Parse | Consent dialog → short-lived `parse-session` → upload this file → result written back locally |
| Sync | Enabled in settings + backup passphrase → AES-GCM ciphertext snapshot → server cannot decrypt |
| Push | Enabled in settings → token bound only to `appUserId` → generic reminder copy; revocable anytime |
| Device migration | Restore with same `appUserId` + passphrase; or export/import JSON |
| Delete cloud | One-tap delete of the cloud ciphertext copy |

---

## Repository layout

| Path | Description |
|------|------|
| `apps/mobile` | Flutter main app (local-first, v0.1 features below) |
| `services/api` | NestJS: parse queue, ciphertext sync, optional accounts |
| `services/parse-worker` | Python: Skill templates + LLM fallback |
| `packages/domain-types` | Shared domain types |
| `.github/workflows` | CI (smoke / E2E / flutter analyze) |
| `apps/miniapp` / `apps/web` / `apps/doctor-web` | Later clients (scaffolding) |

---

## App features (v0.1 · local-first)

| Module | Capabilities |
|------|------|
| **Home** | Dashboard: today's management, quick actions, local stats |
| **Check-in** | Symptom diary: pain / bowel count / diarrhea / Bristol / 3-level blood / urgency / mucus / nausea / fatigue / overall feeling; saving auto-syncs detailed bowel history |
| **Injection** | Protocol scheduling (e.g. Skyrizi), timeline, local reminders, "done today" |
| **Analysis** | Indicator trends · course timeline · exam/surgery · detailed bowel records (incl. check-in-synced) · visit summary · **flare warning** · **surveys** (PHQ-9 / IBDQ / MiniQoL / SF-36) · **CSV export** · system notification test |
| **Me** | App UUID, SQLCipher status, cloud sync/backup/export, system push (opt-in), AI & reminder notes |
| **Labs** | Unified "enter lab result": panel manual entry (major/minor items); or consent to upload a report for parsing, result fills the same form, confirm to write locally |
| **Medication** | Current regimen, switch chain, stop reasons (encryptable), history |

Bottom navigation: `Home · Check-in · Injection · Analysis · Me`

### Run the app

```bash
# Emulator API base: http://10.0.2.2:3000
cd apps/mobile
pwsh ./bootstrap.ps1
flutter run --dart-define=IBD_API_BASE=http://10.0.2.2:3000
# Real device: http://<your-LAN-IP>:3000
```

Offline-capable: entering lab results, medication, injection schedules, symptom check-in, browsing the analysis page.

---

## Optional backend (parse / sync)

```bash
pnpm install
pnpm --filter @ibd/api build

export DATABASE_URL=postgres://ibd:ibd@127.0.0.1:5433/ibd
export REDIS_URL=redis://127.0.0.1:6380
export STORAGE_DRIVER=local
export STORAGE_LOCAL_DIR=var/uploads   # API and Worker must match
export PUBLIC_BASE_URL=http://<your-LAN-IP>:3000
export RUN_MIGRATIONS=true
export STORAGE_SECRET=<non-default>
export JWT_SECRET=<non-default>

pnpm --filter @ibd/api migration:run
node services/api/dist/main.js

# In another terminal: parse-worker
cd services/parse-worker
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.lock
PORT=8081 python -m app.main
```

One-shot (Windows):

```powershell
pwsh ./scripts/dev.ps1           # local Postgres/Redis
pwsh ./scripts/dev.ps1 -Docker   # copy .env.example → .env first
```

Or `make dev` / `make dev-local`. Variable reference: [docs/configuration.md](docs/configuration.md).

| Service | Address |
|------|------|
| API | `http://localhost:3000` · Swagger `/docs` |
| Worker | `:8081` |
| Queue | BullMQ `parse` |

### Key APIs (summary)

| Capability | Endpoint |
|------|------|
| Parse/sync/push short session | `POST /api/v1/auth/parse-session` · `sync-session` · `push-session` `{ appUserId }` |
| Ciphertext sync | `POST/GET/DELETE /api/v1/sync/ciphertext*` |
| System push | `POST/DELETE/GET /api/v1/push/devices` · `POST /api/v1/push/notify` (generic copy; dry-run without `FCM_*`) |
| Parse | `POST /api/v1/parse/jobs` · `POST /:id/confirm` (persist Skill) |
| Direct upload | `POST /api/v1/files/presign` → `PUT uploadUrl` |
| Optional account link (not a login wall) | `POST /api/v1/auth/login` (reserved for phone linking; dev code `123456`, **never for production**) |
| Medication / injection | Swagger: switch chain, protocol scheduling, due reminders |

### LLM (optional)

Without configuration: Skill miss → suggest manual entry. With configuration: uses an OpenAI-compatible API.

| Env var | Description |
|----------|------|
| `LLM_API_BASE` | Compatible gateway |
| `LLM_API_KEY` | Key |
| `LLM_MODEL` | Default `gpt-4o-mini` |

---

## Verification & CI

```bash
pnpm --filter @ibd/api smoke:env
pnpm --filter @ibd/api smoke:entities
pnpm --filter @ibd/api smoke:migration
pnpm --filter @ibd/api smoke:storage
pnpm --filter @ibd/api smoke:push-copy
pnpm --filter @ibd/api e2e:fullstack
pnpm --filter @ibd/api e2e:injection
pnpm --filter @ibd/api e2e:medication
cd services/parse-worker && python -m app.tests.test_ai_engine
cd services/parse-worker && python -m app.tests.test_lab_data_consistency
# Backup + parse chain
node services/api/scripts/e2e-backup-ai.mjs
```

| Workflow | Contents |
|----------|----------|
| `ci.yml` | Node/pnpm build + typecheck + smoke · Python AI unit tests · lab-data consistency guard · full `flutter test` · `flutter analyze` (blocks on warnings/errors) |
| `ci-fullstack.yml` | Postgres+Redis + `scripts/ci-fullstack.sh`: e2e fullstack / injection / medication / backup-ai |

Actions: https://github.com/HPNY/IBD-Management-Software/actions

---

## Security notes

- Local DB **SQLCipher**, key in Android Keystore / iOS Keychain
- Cloud backup AES-GCM + PBKDF2 (backup passphrase + appUserId); server holds only cipher / nonce / mac
- Parse upload requires the user to tap "consent"; `parse-session` expires in ~30 minutes
- System push is opt-in: token bound only to `app_user_uuid`; payload is generic copy, no drug/dose/PHI ([boundary notes](docs/push-privacy.md))
- Uninstall + reinstall loses the local key → export JSON or upload an encrypted snapshot first
- Production refuses to start with `DEV_SMS_CODE` / default secrets / `DB_SYNC=true` / `PUBLIC_BASE_URL` containing localhost (see `env-guard`)

---

## Milestones

| Tag | Contents |
|------|------|
| **v0.1.0** | Local-first MVP: labs/medication/injection/check-in, SQLCipher, parse+Skill, ciphertext sync, dashboard UI & five tabs, analysis page (trends/timeline/exams & surgery/bowel/summary/flare warning), smoke/E2E green (not device-verified) |

Open items are tracked in the **[session worklist](docs/session-worklist.md)** (real-device acceptance, real push, WeChat mini program, PC Web, delete source after parse, doctor client, etc.). Config hardening is complete ([checklist](docs/config-hardening-checklist.md)). System push (local baseline + FCM opt-in) is described in [push-privacy](docs/push-privacy.md).

### Worklist status rules

**Whenever work starts, the corresponding item in [docs/session-worklist.md](docs/session-worklist.md) must first be set to `进行中` (in progress); on completion set it to `已完成` (done); if blocked set `阻塞` (blocked) and state the reason.**

- Changing only the task board but not the checklist file is treated as non-compliance.
- Any new open item must also be written to the checklist (add ID, task, acceptance criteria, status `待办`).
- **Any new work (feature, bugfix, review leftovers, docs, triage notes) must be written into [docs/session-worklist.md](docs/session-worklist.md)** with ID / task / status / acceptance; this avoids losing context across sessions. A board item without a checklist entry is treated as non-compliance.
- At delivery wrap-up, reconcile the checklist against the implementation; leaving "code done but checklist unchecked" (or the reverse) is forbidden.

### Secondary verification rules (mandatory)

**After writing code, a second pass to check for bugs is required before the item may be marked done.** Do not mark checklist/task as done without verification.

Minimum verification checklist:

1. **Compile / static analysis**: `tsc` / `flutter analyze` / the corresponding build command passes with zero errors
2. **Duplication & truncation**: after editing the same file multiple times, confirm no duplicated blocks or truncated syntax (matching quotes/brackets)
3. **Security**: new endpoints / deletes / upload paths have ownership checks (anti-IDOR); no OWASP Top 10 introduced
4. **Consistency**: caller signatures match the implementation; checklist/docs match real behavior
5. **Regression points**: run the main path for every entry touched (or state the blocking reason it cannot run)

Any issue found during verification must be **fixed on the spot** and re-verified; anything not immediately fixable must be recorded in [session-worklist](docs/session-worklist.md).

---

## License & contributions

A personal medical-data project; local by default, minimal upload. Issues / PRs welcome.

## License

This project is licensed under **GNU Lesser General Public License v3.0 or later (LGPL-3.0-or-later)**. See [LICENSE](LICENSE).

本项目采用 **GNU Lesser General Public License v3.0 or later (LGPL-3.0-or-later)**。详见 [LICENSE](LICENSE)。