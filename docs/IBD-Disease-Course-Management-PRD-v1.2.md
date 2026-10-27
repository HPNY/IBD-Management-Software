# IBD Disease-Course Management Program — Product Requirements Document (PRD)

> Designed based on real-world disease-course management experience of a Crohn's disease patient

---

> **Document version: V1.2 (revision date 2026-10-27)**
> This version builds on V1.1 (the "aligned-with-implementation" revision): after the **P0 batch (T1–T7, acceptance signed off by the user on 2026-10-27)**, the implementation changes were re-checked and statuses updated; the §7 remaining-to-do list was refreshed accordingly. The V1.0 text is [IBD-Disease-Course-Management-PRD.md](IBD-Disease-Course-Management-PRD.md) (English) / [IBD病程管理程序PRD.md](IBD病程管理程序PRD.md) (Chinese); V1.1 is [IBD-Disease-Course-Management-PRD-v1.1.md](IBD-Disease-Course-Management-PRD-v1.1.md) / [IBD病程管理程序PRD-v1.1.md](IBD病程管理程序PRD-v1.1.md); this English V1.2 is translated from the Chinese V1.2 [IBD病程管理程序PRD-v1.2.md](IBD病程管理程序PRD-v1.2.md). Audit and acceptance evidence is in [var/prd-audit/](../var/prd-audit/) and [audit-evidence/](audit-evidence/) (the P0 acceptance report has been signed off by the user).
>
> **Implementation status legend**: ✅ Implemented ｜ ⚠️ Partially implemented / weaker than designed ｜ ❌ Not implemented (still planned) ｜ ➕ Implementation exceeds what this document describes

---

## 1. Product Overview

### 1.1 Product Name
**IBDers** — Disease-Course Self-Management Platform for IBD Patients

### 1.2 Product Positioning
A **disease-course recording and self-management tool** for patients with inflammatory bowel disease (IBD, including Crohn's disease and ulcerative colitis). It helps patients systematically manage laboratory data, medication records, examination images, injection schedules, and other full-course disease information, supporting doctor-patient communication and treatment decisions.

### 1.3 Target Users
- **Core users**: Patients diagnosed with IBD (Crohn's disease, ulcerative colitis)
- **Extended users**: Patient families/caregivers, gastroenterologists (viewing patient self-managed data)

### 1.4 Product Background
IBD is a chronic disease requiring lifelong management. Take the experience of a typical Crohn's disease patient:

```
Diagnosis → Drug therapy → Poor response & medication switch → Surgery → Post-op recovery → Multiple regimen adjustments
     → Biologic injections → Regular lab rechecks → Imaging/endoscopy follow-up
```

Information-management pain points patients face throughout this journey:
- **Scattered lab reports**: Paper reports, PDFs, hospital apps — fragmented data
- **Difficulty tracking indicator trends**: Cross-year comparison of key indicators such as CRP, fecal calprotectin, and ESR is difficult
- **Complex medication history**: Multiple drugs, dose adjustments, and reasons for discontinuation require complete records
- **Easily missed injection schedules**: Biologics have strict injection time windows
- **Doctor-patient information asymmetry**: Patients struggle to present a complete medical history clearly to doctors

---

## 2. Core Features

### 2.1 Laboratory Data Management

#### 2.1.1 Intelligent PDF Report Parsing

**Feature description**: Supports uploading hospital lab/examination report PDFs, uses **AI intelligent recognition** to automatically extract key data, and generates parsing templates (Skills) for hospital formats that have been parsed before — achieving "the more you use it, the more accurate it becomes."

> **Implementation status (2026-10-27) ⚠️**: Dual-engine parsing is implemented, but the **engines run server-side** (`services/parse-worker`: Skill template hit → on miss, falls back to LLM/Vision parsing); the App/PC Web clients handle upload, confirmation, and "delete-after-use". The Skill template's `check_fn`, cross-line (multiline) extraction, and "partial Skill hit → AI completion" are **all not implemented**; the parsing `accuracy` field exists but is never computed; the data-source label has been **fixed (T2)**: the server writes `skill|ai` from the job's real engine and the App writes all three values truthfully; old data is not back-filled. The App-side local Skill cache has been **closed out (T3)**: local fast path for .txt text reports (local match only when fully hit; the file is not uploaded), clearable, and format-mismatch auto-invalidates.

##### Parsing Architecture: Dual-Engine Mode

```
User uploads PDF
    │
    ▼
┌──────────────────────┐
│  Skill template match  │ ←── Learned hospital-format template library
│  (priority hit)        │
└──────────┬───────────┘
           │ miss
           ▼
┌──────────────────────┐
│  AI intelligent        │ ←── LLM + Vision capabilities
│  parsing engine        │
│  (general fallback)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Structured data       │
│  output + user         │
│  confirmation/correction│
└──────────┬───────────┘
           │ first parse succeeds
           ▼
┌──────────────────────┐
│  Auto-generate/update  │ ←── Deposited as the hospital's parsing template
│  Skill                 │
└──────────────────────┘
```

##### Engine 1: Skill Template Parsing (Fast Lane)

**Core idea**: Each hospital's report format is fixed. After the first parse, a Skill template is generated; subsequent reports of the same kind are directly extracted with the template — faster and more accurate.

**Skill template content** (✅ core implemented; `check_fn`/`multiline` see the notes below):
```yaml
hospital: Tertiary Hospital A
report_type: Complete Blood Count (5-part differential)
version: 1.2
last_updated: YYYY-MM-DD

# Date extraction rules (✅ primary/fallback dual rules implemented)
date_extraction:
  primary: '(\d{8})G\d+'  # Sample number format
  fallback: 'Collection Date:\s*(\d{4})/(\d{1,2})/(\d{1,2})'

# Item extraction rules
items:
  - name: White Blood Cell Count
    alias: WBC
    pattern: 'White Blood Cell Count\s+([\d.]+)'
    multiline: true  # ⚠️ Field can be stored, but the parsing engine does not execute cross-line logic for now
    unit: '10^9/L'
    ref_range: [3.5, 9.5]
    check_fn: 'v < 3.5 or v > 9.5'   # ❌ Not implemented; abnormality flagging actually uses numeric comparison against ref_range

  - name: Hemoglobin
    alias: Hb
    pattern: 'Hemoglobin\s+([\d.]+)'
    unit: 'g/L'
    ref_range: [130, 175]

  # ... more items

# Special handling rules (⚠️ only two built-in hardcoded rules: patient_id_mismatch / crp_multiline)
special_rules:
  - filter: 'patient_id_mismatch'  # Filter medical-record-number mismatches
  - filter: 'crp_multiline'  # Cross-line handling for CRP
```

**Skill template management** (⚠️ partially implemented):
- Each hospital can have multiple Skills (separated by report type) — ✅ (`hospital+reportType` unique key, minor version increments + `parentVersion` version chain)
- Skill version is auto-updated after user corrections — ✅ (the parse-confirm endpoint auto-creates/bumps versions)
- Skills are **shared** among users (community contributions) — ✅ (Web Skill community: scrubbed publishing, ratings, collaborative version bumping; no community UI on the App yet)
- Export/import of Skill templates — ✅ Web-side JSON import/export; none on the App
- Parsing accuracy statistics / usage count — ⚠️ `usageCount` is counted; the `accuracy` field exists but has no computation logic
- App-side local Skill cache — ✅ closed out (T3): local fast hit for .txt reports (file not uploaded), clearable in Settings, format-mismatch auto-invalidation; PDF/images still go through the cloud

##### Engine 2: AI Intelligent Parsing (General Fallback)

**Applicable scenarios**:
- Hospital report formats seen for the first time (no Skill template)
- Image-based/scanned PDFs (multimodal LLM recognition)
- Unusual report formats (non-standard layout; **handwritten-annotation recognition is not supported for now** ❌)

**AI parsing flow** (✅ implemented; Vision depends on multimodal model configuration):

| Step | Handling | Description |
|------|----------|-------------|
| 1. PDF reading | pymupdf | Extract text directly from text-based PDFs; pages with fewer than 40 characters of text are treated as scans and rasterized at 3x zoom |
| 2. Text/image understanding | Large language model (OpenAI-compatible API; up to 4 page images sent to the model) | Input raw text or images; AI understands the report structure and content |
| 3. Structured extraction | AI + rule validation | Output standardized JSON (item name / value / unit / reference range) |
| 4. Abnormality annotation | Rule engine | Automatically flag ↑/↓ according to reference ranges |
| 5. Result confirmation | User interaction | User confirms/corrects the extraction results; corrections feed back into the Skill |

**AI prompt design example** (✅ same source as the implementation):
```
You are a medical laboratory report parsing assistant. Please extract all test items
from the following lab report text and return them in JSON format with these fields:
- name: item name
- value: numeric result (float)
- unit: unit of measure
- ref_min: lower bound of the reference range (if any)
- ref_max: upper bound of the reference range (if any)
- flag: abnormality flag (↑/↓/null)

Special notes:
1. In some reports the item name and its value appear on two lines — identify the association
2. Filter out medical record numbers, sample numbers, and other non-lab numeric values
3. Distinguish upper-bound values like ">1800" from concrete values

Report text:
{report_text}
```

##### Dual-Engine Collaboration Mechanism

| Scenario | Processing path | Speed | Accuracy |
|----------|----------------|-------|----------|
| Skill template available | Template parsing → output | Extremely fast (<1s) | Extremely high (99%+) |
| First report from this hospital | AI parsing → user confirmation → generate Skill | Slower (3–5s) | High (95%+) |
| Image-based PDF | Vision AI → user confirmation | Slower (5–10s) | Moderately high (90%+) |
| Skill parsing fails | Fall back to AI parsing → update Skill | Medium | High |

> ⚠️ Speed/accuracy in the table above are **design targets**; there is currently no measured statistics. The AI path depends on LLM response times (default timeout 60s) and carries no <5s guarantee — see §4.3.

**Skill auto-generation/update logic** (⚠️ partially implemented):
1. User uploads a PDF, no matching Skill → AI parsing → user confirmation → **automatically generate a new Skill** ✅
2. User uploads a PDF, Skill parsing succeeds but misses fields → AI completes → user confirmation → **automatically update the Skill version** ❌ (a Skill hit returns immediately; there is no AI-completion step)
3. User manually corrects AI/Skill parsing results → **feed corrections back into the Skill** ✅
4. User gets tested at different hospitals → maintain independent Skills keyed by hospital (+ report type) ✅

**Output format** (⚠️ partially implemented):
- Chinese item names (not English abbreviations) ✅
- Chronologically arranged structured data tables ✅
- Abnormal values marked with ↑↓ ✅
- Data source labels (Skill parsing / AI parsing / manual entry) ✅ written truthfully (T2: confirm uses the real engine; the App writes all three values; old data is not back-filled)

#### 2.1.2 Manual Entry
**Feature description**: Supports manual entry of lab data, adapted to the following scenarios:
- The report is on paper or an image and cannot be auto-parsed
- Historical data needs to be back-filled
- The patient is tested at different hospitals with inconsistent report formats

**Entry UI design** (✅ implemented):
- Grouped by test category (CBC, liver function, inflammatory markers, etc.) ✅
- Each indicator displays its reference range as an input reference ✅
- Entering an out-of-range value automatically prompts ↑ or ↓ ✅
- ➕ Custom lab rows (items beyond the fixed panels)

#### 2.1.3 Indicator Trend Analysis
**Feature description**: Displays time trends of key indicators in chart form.

**Core IBD indicator panel** (✅ implemented, 7 core indicators):

| Indicator | Reference range | Clinical significance |
|-----------|----------------|----------------------|
| High-sensitivity C-reactive protein (hs-CRP) | <5.0 mg/L | Systemic inflammatory activity |
| Erythrocyte sedimentation rate (ESR) | <15 mm/h | Inflammatory activity (lagging indicator) |
| Fecal calprotectin | <200 μg/g | **Gold standard for intestinal inflammation**, most sensitive |
| Lymphocytes | 1.1–3.2×10⁹/L | Immune status; infection risk under medication |
| Albumin | 40–55 g/L | Nutritional status |
| Hemoglobin | 130–175 g/L | Anemia assessment |
| Uric acid | 208–428 μmol/L | Drug side-effect monitoring |

**Trend analysis features** (⚠️ varies widely by client):
- Customizable time ranges (3 months / 6 months / 1 year / all) — ✅ PC Web (3M / 1Y / all); ❌ not on the App
- Multi-indicator overlay comparison (e.g., CRP + calprotectin) — ✅ PC Web ECharts; ❌ App has a single-indicator line chart
- Mark medication-change nodes on the chart — ❌ not implemented (only the "AI/Rules Analysis" page offers **before/after medication mean comparison** in text form ➕)
- Key threshold lines (e.g., the calprotectin 200 remission line) — ❌ not implemented
- Generate trend summary text — ⚠️ the App trend page shows only min/max/point count; rising/falling/stable direction summaries and abnormality hints live on the "AI/Rules Analysis" page ➕

#### 2.1.4 Examination/Imaging Report Management
**Feature description**: Manages non-lab examination reports (CT, MRI, ultrasound, endoscopy, pathology, etc.).

**Supported examination types**:
- Imaging: CT, MRI, X-ray, ultrasound
- Endoscopy: gastroscopy/colonoscopy reports
- Pathology: biopsy pathology reports
- Special examinations: capsule endoscopy, small-bowel contrast studies, etc.

**Structured storage** (⚠️ partially implemented):
- Examination date, type, body part ✅ (the entry form also has findings/score)
- Key findings (text summary) ✅
- Diagnostic conclusion, comparison with previous examinations (e.g., "improved compared with prior") ⚠️ data column exists, no entry path
- Scoring-system records (e.g., SES-CD, Limberg grade, IBUS-SAS score) ⚠️ score is free text; the dashboard already extracts **Limberg / SES-CD** trends via regex; IBUS-SAS is unsupported
- Imaging/report attachments ❌ not implemented

---

### 2.2 Medication Management

#### 2.2.1 Current Medication Regimen
**Feature description**: Records all medications currently in use and their detailed information.

**Drug information fields** (⚠️ one difference: no standalone "indication" field; merged into notes/adjustment reason):

| Field | Description | Example | Status |
|-------|-------------|---------|--------|
| Drug name | Generic + brand name | Upadacitinib (Rinvoq) | ✅ |
| Drug class | Mechanism-based class | JAK inhibitor | ✅ |
| Indication | Treatment goal | Crohn's disease maintenance therapy | ⚠️ merged into notes/adjustment reason |
| Dose | Single dose | 15 mg | ✅ |
| Frequency | Dosing frequency | Once every other day | ✅ (with frequency↔time-of-day linkage) |
| Route | Oral/subcutaneous/intravenous | Oral | ✅ |
| Start date | Date started | — | ✅ |
| Status | Active/paused/discontinued | Active | ✅ |

#### 2.2.2 Medication History Timeline
**Feature description**: A complete record of all previously used medications, dose adjustments, and reasons for discontinuation.

**Recorded dimensions** (⚠️ partially implemented):
- Medication-switch chain + reasons for discontinuation ✅ (the server also has an adjust/pause/resume/stop/switch medication-chain API ➕)
- Side-effect records (shingles, recurrent infections, etc.) and severity ⚠️ the data table and server API exist, but **there is no App entry/display UI**
- Independent dose-adjustment records ❌ (editing is "stop the old & create a new"; there are no standalone adjustment events)
- Duration of discontinuation and recovery process ✅ (reflected by start/end dates)

**Timeline visualization** (✅ lists history by start date; the full disease-course timeline is in §2.4.1):
```
2023     2024        2025                    2026
├─Humira─┤─Anjianning──┤─Upa 3 tabs→stop→1 tab→stop→┤─Upa qod──────→
                                                   └─+Risankizumab─→
                              ↑shingles    ↑persistent cold
```

#### 2.2.3 Biologic Injection Management
**Feature description**: Injection-schedule management designed specifically for patients on biologics.

**Supported injectable drugs** (✅ 8 implemented, beyond the original list of 5):
- Risankizumab (Skyrizi/喜开悦) — IL-23 inhibitor
- Infliximab (Remicade/类克) — TNF-α inhibitor
- Adalimumab (Humira/安健宁) — TNF-α inhibitor
- Ustekinumab (Stelara/喜达诺) — IL-12/23 inhibitor
- Vedolizumab (Entyvio/安吉优) — integrin inhibitor
- ➕ Golimumab, certolizumab, Upadacitinib (oral), etc.

**Injection scheduling features** (⚠️ partially implemented):
- Automatically generate an injection calendar from the drug regimen ✅ (start date + fixed interval + month-calendar preview)
- Distinguish different frequencies for induction vs. maintenance phases ⚠️ **not wired in**: the App generates by a single interval and the phase is a pseudo-label (induction/maintenance protocol tables are defined but not connected); the server stores an induction/maintenance protocol library for 4 biologics
- Reminders X days before injection (configurable, default 3 days) ✅ multiple lead-time options (day-of / 1 / 2 / 3 / 7 days, configured in Settings, T4); one local notification per lead time
- Record the actual injection date of each dose (may deviate from plan) ✅ ("Injected today")
- Automatically adjust subsequent schedules after a delayed injection ❌ not implemented (recording an actual date does not shift later planned dates)

**Risankizumab schedule example**:
```
Induction (IV infusion 600 mg):
  Week 0  → [date] ✅
  Week 4  → [date] ✅
  Week 8  → [date] ✅

Maintenance (subcutaneous injection, once every 8 weeks):
  Week 12 → [date] ⏳ first subcutaneous dose
  Week 20 → [date]
  Week 28 → [date]
```

---

### 2.3 Surgery Record Management

#### 2.3.1 Structured Storage of Surgery Information
**Feature description**: Records complete surgical information, supporting text + image attachments.

**Field design** (⚠️ the entry UI has only 6 fields; the rest have columns but no entry path):

| Field | Description | Status |
|-------|-------------|--------|
| Surgery date | Precise to the day | ✅ |
| Surgery type | Resection / reconstruction / stoma, etc. | ✅ |
| Operative site | Small bowel / colon / rectum, etc. | ✅ |
| Intraoperative findings | Lesion description (text + schematic) | ⚠️ column exists, no entry path; schematic ❌ |
| Procedure | Specific operative description | ✅ |
| Resected length | Length of bowel resected | ✅ |
| Anastomosis type | KONO-S / end-to-end / side-to-side, etc. | ⚠️ column exists, no entry path |
| Intraoperative score | e.g., Crohn's disease surgery score | ❌ |
| Postoperative score | Post-op assessment | ❌ |
| Surgeon | Name | ✅ |
| Attachments | Surgery record photos/scans | ❌ |

#### 2.3.2 Surgical Schematic Management
**Feature description**: Supports uploading intraoperative schematics with annotations of lesion locations and surgical procedures.

- ❌ **Entire section not implemented**: the App has no image upload/annotation capability at all; the "total bowel length / remaining length" fields do not exist either.

---

### 2.4 Disease-Course Timeline

#### 2.4.1 Full Disease-Course Timeline
**Feature description**: Integrates all disease-course events into one complete timeline.

**Timeline event types** (⚠️ 2 types missing):
- 🔴 Disease events (diagnosis, relapse, complications) — ❌ not implemented
- 🟡 Examination events (labs, imaging, endoscopy, pathology) — ✅
- 💊 Medication events (starting / adjusting / stopping drugs) — ✅
- 🏥 Surgery events — ✅
- 💉 Injection events — ✅
- ⚠️ Adverse-reaction events — ❌ not implemented (no side-effect UI; see §2.2.2)
- ➕ Quality-of-life assessment events

**Interaction design** (⚠️ partially implemented):
- Zoom by year/month — ❌
- Filter by event type — ✅
- Click an event to view details — ❌ (list items have no detail navigation)
- Export to PDF (to show the doctor at visits) — ❌ (export capability is in §4.1: CSV/JSON/Excel/print)

#### 2.4.2 Visit Summary Generation
**Feature description**: Automatically generates a structured visit summary so patients can quickly report their condition to doctors during outpatient visits.

> **Implementation status (2026-10-26) ⚠️**: The App can one-click generate summary text (current medications ✅, recent core labs ✅, recent injections ➕, symptom summary ➕), but **patient info and recent-imaging sections are missing**; "Items of concern" is a fixed disclaimer sentence rather than auto-generated content; after generation only re-generation is supported — **no sharing/export**. The Doctor Web additionally has a server-assembled disease-course summary (last 5 labs / 7 days of symptoms / medications / pending injections) that can be copied ➕.

**Summary content**:
```
[Patient info] [Name], male, [age] years old, diagnosed with Crohn's disease for 3+ years

[Current medications]
1. Upadacitinib, 1 tablet every other day (JAK inhibitor)
2. Risankizumab, maintenance phase, subcutaneous injection every 8 weeks

[Recent labs ([date 3])]
[CRP value] | [ESR value] | [calprotectin value]
[lymphocyte value] | [uric acid value]

[Recent imaging]
Abdominal ultrasound ([date]): Limberg grade [grade], [findings]

[Items of concern]
1. Calprotectin remains elevated; continued monitoring needed
2. Lymphocytes persistently low; infection risk
3. Long-standing hyperuricemia
```

---

### 2.5 Reminders and Follow-up

> **Implementation status (2026-10-27) ✅ core delivered (T4/T6)**: All three reminder kinds are **local notifications** (network-independent) with **sanitized copy** (no drug names / dosages / medical-record fields; fixed by tests): injection (configurable multiple lead times, including a day-of tier), medication (daily at a configurable time, off by default, created per active medication / cancelled on stop), and recheck (user-defined dates, create/cancel persisted); a unified scheduler reschedules all three at once. Remote push (FCM) is optional and has not yet been verified on real devices due to missing Firebase credentials; OBI video reminders and automatic recheck-item suggestions are **still not implemented**. Medication-adherence check-in ✅ (morning/noon/evening slots + monthly calendar).

#### 2.5.1 Injection Reminders
- Push reminders 3 days and 1 day before injection — ✅ multiple lead-time options (day-of / 1 / 2 / 3 / 7 days) local notifications (T4)
- On injection day, remind the patient to bring relevant documents/insurance card — ✅ generic day-of copy (T6)
- For subcutaneous drugs, remind the patient to watch the OBI (on-body injector) instructional video — ❌

#### 2.5.2 Recheck Reminders
- Automatically suggest recheck timing based on the medication regimen — ❌ (compliance constraint: no auto-generated medical advice; copy states "follow your doctor's orders")
- Remind about the list of items to be rechecked — ❌
- Custom reminders supported — ✅ user-defined-date reminders (T6, create/cancel persisted)

#### 2.5.3 Medication Reminders
- Daily/every-other-day reminders for oral medications — ⚠️ daily timed reminders implemented (T6, per active medication, configurable hour); dosing-frequency linkage (e.g., every-other-day) not done
- Record medication adherence — ✅ medication check-in calendar / per-slot statistics ➕

---

### 2.6 Data Visualization

#### 2.6.1 Disease Activity Dashboard
**Feature description**: Combines multiple indicators to display current disease activity.

> **Implementation status (2026-10-26) ✅**: The home-page disease-activity card + detail page are implemented.

**Dashboard elements**:
- Inflammatory triad status lights (CRP / ESR / calprotectin) ✅
- Limberg grade trend (ultrasound) ✅
- SES-CD score trend (endoscopy) ✅
- Current medication regimen cards ✅
- Countdown to next injection/recheck — ⚠️ injection countdown ✅; recheck countdown ❌ (no "next recheck" data model)

#### 2.6.2 Annual Health Report
**Feature description**: Automatically generates an annual health summary report each year.

> **Implementation status (2026-10-26) ✅ core implemented** (the V1.0 "provisional manual implementation" note is outdated and has been removed in this version): entering the report page auto-builds the **most recent complete year** report; it includes **year-over-year comparison with the previous year** (lab count / check-in days / injection count / average abdominal pain), **examination/surgery summaries**, medication adjustment records, and text sharing. Still missing: automatic cross-year push, an "annual key-indicator trend" chart (labs are currently counts only), and a PDF report.

**Report content**:
- Annual trend of key indicator changes — ⚠️ counts and YoY comparison only, no trend chart
- Medication adjustment records ✅
- Examination/surgery record summaries ✅
- Comparison with the previous year ✅

---

### 2.7 Symptom and Quality-of-Life Management

> This module draws on the design philosophy of competitors such as MyCrohnsAndColitisTeam and MyGut, filling the gap of the early PRD regarding patients' daily self-management.

#### 2.7.1 Daily Symptom Diary
**Feature description**: Spend 1–2 minutes each day recording the day's symptom status, building longitudinal symptom data.

**Recorded items** (✅ all implemented):

| Category | Item | Format | Status |
|----------|------|--------|--------|
| Abdominal pain | Severity (0–10) | Slider | ✅ |
| Diarrhea | Frequency + character (Bristol Stool Form Scale 1–7) | Number + selection | ✅ |
| Bloody stool | None / mild / obvious | Single select | ✅ |
| Bloating | Severity (0–10) | Slider | ✅ Implemented (T1); legacy dirty values were migrated to NULL with marks (notice card, no silent overwrite) |
| Fatigue | Severity (0–10) | Slider | ✅ |
| Nausea | Yes/No | Toggle | ✅ |
| Mouth ulcers | Yes/No | Toggle | ✅ |
| Joint pain | Yes/No + location | Toggle + selection | ✅ (knee / ankle / hand / elbow / back / other) |
| Custom | Patients can add personal items of concern | Text | ✅ |
| Overall feeling | Better than yesterday / same / worse | Single select | ✅ |

**Interaction design** (✅):
- A persistent "Today's check-in" entry on the home page, completable within 1 minute ✅
- Quick templates supported ("same as yesterday" / "better/worse than yesterday") ✅
- Calendar view: color depth indicates symptom severity ✅ (a 6-week heat calendar; unrecorded days in gray)
- Unrecorded dates shown in gray to encourage continuous logging ✅

#### 2.7.2 Bowel Movement Records
**Feature description**: Fine-grained tracking of bowel movements — the most core daily indicator for IBD patients.

**Recorded items** (✅ all implemented; check-in auto-syncs to the detail table, avoiding duplicate entry ➕):
- Time ✅
- Count (daily cumulative) ✅
- Character (Bristol Stool Form Scale, types 1–7) ✅
- Urgency (yes/no) ✅
- Blood (none / on wiping / obvious) ✅
- Mucus (yes/no) ✅

**Data value**:
- Correlation analysis with calprotectin, CRP, and other indicators — ⚠️ not implemented (what is implemented is **food × bowel-movement correlation** observation analysis ➕, see §5.5)
- Discover food–bowel-movement patterns ✅ (with lag windows)
- Provide objective data at visits instead of subjective descriptions ✅

#### 2.7.3 Flare Warning (Flare Checker)
**Feature description**: Based on symptom data and historical patterns, assess whether there is a current flare risk.

> **Implementation status (2026-10-26) ⚠️**: The three-level warning is implemented, but the judgment is a **local rules engine** (thresholds + consecutive worsening), not AI/ML; it does not reference historical pre-flare patterns; the 🔴 level lacks the "fever >38°C" condition (no body-temperature field); the warning summary has no outbound sharing; assessment results are **not persisted** (no FlareAssessment storage, no confidence score).

**Three-level warning mechanism** (✅ rules-based):

| Level | Trigger condition | Suggestion |
|-------|-------------------|------------|
| 🟢 Normal | Symptom scores stable, bowel movements normal | Continue observation |
| 🟡 Watch | Symptoms worsening for 3 consecutive days, or sudden increase in bowel movement frequency | Suggest rechecking CRP + calprotectin soon |
| 🔴 Alert | Bloody stool, severe abdominal pain (fever condition not implemented) | Seek medical attention immediately |

**AI-assisted judgment** (❌ target design, not implemented for now):
- Combine daily symptom data + latest lab indicators + medication status for comprehensive assessment — ⚠️ only one line of recent lab text
- Reference pre-flare symptom patterns from history — ❌
- Automatically generate a symptom summary when a warning triggers, ready to send to the doctor — ❌

#### 2.7.4 Quality-of-Life Assessment
**Feature description**: Regularly assess the overall impact of the disease on quality of life.

**Assessment scales** (⚠️ scales are complete, but the scoring differs from the original):
- **SF-36** (general quality-of-life scale) ✅ 36 items; ⚠️ simplified uniform 0–4 scoring + self-computed 8-domain 0–100 domain scores, not the original weights/norm-based conversion (no PCS/MCS); plus domain-score trends ➕
- **IBDQ** (IBD-specific quality-of-life scale) ⚠️ short form, 10 items
- **PHQ-9** (mental health screening) ✅
- ➕ MiniQoL mini-scale, 5 items
- "Once a month / once a quarter" cadence ❌ no reminders/due prompts; fully manual

**Application scenarios**:
- Longitudinal tracking of quality-of-life trends ✅
- Assess the overall quality-of-life improvement brought by treatment plans ⚠️ (combined with the before/after medication comparison on the AI/Rules Analysis page)
- Identify mental-health risks (PHQ-9 grading) ✅

#### 2.7.5 Sleep and Stress Tracking
**Feature description**: Sleep quality and psychological stress are important triggers for IBD flares.

**Recorded items** (✅ all implemented, merged into one daily check-in save):
- Sleep duration ✅
- Sleep quality (1–5) ✅
- Difficulty falling asleep (yes/no) ✅ (field name `sleepInsomnia`)
- Night wakings (count) ✅
- Stress level (1–10) ✅
- Stress source (work / family / disease / other, optional) ✅

**Data correlation** (❌ not implemented):
- Analyze delayed correlations such as "high stress → symptoms worsen a few days later" — ❌ (the only lag correlation in the whole repo is food × bowel movements)
- Identify patterns between sleep quality and abnormal bowel movements — ❌
- Provide patients with quantifiable self-management advice — ❌

#### 2.7.6 Medication Reviews
**Feature description**: Patients give subjective reviews of medications they have used, helping fellow patients as a reference.

**Review dimensions** (✅ all implemented):
- Overall efficacy (1–5 stars) ✅
- Side-effect severity (none / mild / moderate / severe) ✅
- Side-effect types (multi-select: infection, rash, GI reactions, headache, etc.) ✅
- Whether still in use ✅
- Written review (optional) ✅ (upload allow-list validation + hashed signature — privacy hardening ➕)

**Community sharing** (✅ server-side aggregation):
- Aggregate scores by drug ✅ (online aggregation, falling back to local aggregation on failure)
- Filter by IBD type (Crohn's vs. ulcerative colitis) ✅
- Does not replace doctor's advice; for reference only ✅

#### 2.7.7 Local Patient Peers and Care Guides
**Feature description**: Help patients find fellow patients in the same city and quality IBD specialist resources.

**Local patient peers** (⚠️ partially implemented):
- Match IBD patients in the same city based on geographic location ⚠️ actually **manual city selection / dropdown**, not location matching; no precise location collected (privacy design ➕)
- Anonymous display (nickname + city, no real names) ✅ (pseudonymous hash)
- Can form local groups (e.g., "Hangzhou IBD Patient Group") ❌ not implemented
- ➕ Same-city anonymous posts (offline drafts)

**Care guides** (⚠️ static data):
- Recommended IBD specialist hospitals/departments in each city ⚠️ built-in static data for 8 hospitals
- Doctors' areas of expertise (e.g., surgical / medical / complex cases) ⚠️ only coarse-grained tips/specialty
- Care process tips (registration, examinations, hospitalization experience) ❌
- Sharing of medical insurance policy experience ❌

---

## 3. Data Model

### 3.1 Core Entities

> The following is the **target logical model**; implementation gaps against the current code entities are in §3.2 (V1.1 reconciliation).

```
Patient
├── basicInfo: name, gender, date of birth, medical record number, diagnosis date, IBD type
├── medications[]: medication records
├── labResults[]: lab results
├── examinations[]: examination/imaging records
├── surgeries[]: surgery records
├── injections[]: injection records
└── timeline[]: disease-course event timeline

Medication
├── drugName: generic drug name
├── brandName: brand name
├── category: drug class (JAK inhibitor / IL-23 inhibitor / TNF-α inhibitor, etc.)
├── dosage: dose
├── frequency: frequency
├── route: route (oral / subcutaneous / intravenous)
├── startDate: start date
├── endDate: discontinue date (nullable)
├── status: status (active / paused / discontinued)
├── reason: reason for adjustment
└── adverseEvents[]: adverse-reaction records

LabResult
├── date: test date
├── hospital: testing hospital
├── items[]: test item list
│   ├── name: item name
│   ├── value: result value
│   ├── unit: unit
│   ├── referenceRange: reference range
│   └── flag: abnormality flag (↑/↓/empty)
└── source: source (skill｜ai｜manual three values; see §3.2)

Examination
├── date: examination date
├── type: examination type (CT / MRI / ultrasound / endoscopy / pathology)
├── bodyPart: body part examined
├── findings: examination findings
├── diagnosis: diagnostic conclusion
├── score: score (SES-CD / Limberg / IBUS-SAS, etc.)
├── comparison: comparison with previous
└── attachments[]: image/report attachments

Surgery
├── date: surgery date
├── type: surgery type
├── surgeon: operating surgeon
├── findings: intraoperative findings
├── procedure: procedure performed
├── resectedLength: resected length (cm)
├── totalLength: total organ length (cm)
├── anastomosis: anastomosis type
├── intraopScore: intraoperative score
├── postopScore: postoperative score
└── diagram: surgical schematic

Injection
├── drug: drug name
├── plannedDate: planned date
├── actualDate: actual date
├── phase: phase (induction / maintenance)
├── dose: dose
├── route: route (intravenous / subcutaneous)
├── weekNumber: week number
└── notes: notes

ParseSkill
├── hospital: hospital name
├── reportType: report type (CBC / liver function / ultrasound, etc.)
├── version: template version number
├── dateExtraction: date extraction rules (regex)
├── items[]: item extraction rule list
│   ├── name: item name
│   ├── alias: English abbreviation
│   ├── pattern: extraction regex
│   ├── multiline: cross-line supported
│   ├── unit: unit
│   ├── refRange: reference range
│   └── checkFn: abnormality judgment logic
├── specialRules[]: special handling rules
├── source: source (AI-generated / user-contributed / community download)
├── accuracy: parsing accuracy
├── usageCount: usage count
├── sharedToCommunity: published to community or not
└── ratings: community ratings

SymptomDiary
├── date: record date
├── painLevel: abdominal pain severity (0–10)
├── diarrheaCount: diarrhea count
├── stoolType: Bristol Stool Form Scale (types 1–7)
├── bloodyStool: bloody stool (none / mild / obvious)
├── bloating: bloating severity (0–10)
├── fatigue: fatigue severity (0–10)
├── nausea: nausea (yes/no)
├── mouthUlcer: mouth ulcers (yes/no)
├── jointPain: joint pain (yes/no + location)
├── customItems[]: custom record items
└── overallFeeling: overall feeling (better than yesterday / same / worse)

BathroomRecord
├── dateTime: time of bowel movement
├── dailyCount: nth time of the day
├── stoolType: Bristol scale (1–7)
├── urgency: urgency (yes/no)
├── blood: degree of bloody stool
├── mucus: mucus (yes/no)
└── notes: notes

SleepStressRecord
├── date: record date
├── sleepHours: sleep duration
├── sleepQuality: sleep quality (1–5)
├── difficultyFallingAsleep: difficulty falling asleep (yes/no)
├── nightWakes: number of night wakings
├── stressLevel: stress level (1–10)
└── stressSource: stress source

FlareAssessment
├── date: assessment date
├── level: warning level (🟢 normal / 🟡 watch / 🔴 alert)
├── triggerFactors[]: trigger factors
├── symptomSummary: symptom summary
├── recommendation: recommended actions
└── aiConfidence: AI judgment confidence
```

### 3.2 Implementation Gaps (V1.1 Reconciliation)

| Entity | Implementation status |
|--------|----------------------|
| Patient | ✅ server entity complete (incl. medical record number); ⚠️ shared type `PatientBasicInfo` lacks the medical record number |
| Medication | ✅ all ten fields present; adverseEvents is a standalone table + API (not nested); ➕ adjust/pause/resume/stop/switch medication-chain API |
| LabResult | ✅ the three `source` values `skill｜ai｜manual` are written truthfully (T2; old data is not back-filled); ➕ deviceId, HLC hybrid logical clock fields |
| LabItem | ⚠️ name split into `nameNorm/nameRaw`, referenceRange split into `refMin/refMax` |
| Examination | ⚠️ client-local table + Web localStorage only, **no server entity/API**; no attachments |
| Surgery | ⚠️ same as above, client-local table only; no scores/schematics |
| Injection | ✅ matches the target model; ➕ server-side scheduling protocol library and schedule/upcoming/complete APIs |
| (Parse job) ParseJob | ➕ T2 added the `engine` (skill\|ai) persisted field (nullable column + up/down migration, backward compatible) |
| ParseSkill | ⚠️ split into two tables (versions + ratings); no `checkFn`, `multiline` stored but not executed, two hardcoded `specialRules`, `accuracy` column without statistics, `usageCount`/`ratings`/`sharedToCommunity` ✅; source enum is ai_generated/user_confirmed/manual/community |
| SymptomDiary | ⚠️ server lacks mouthUlcer/jointPain/customItems (client-only); the bloating defect is fixed (T1, v10 migration + data_flags marks + compensation script) |
| BathroomRecord | ⚠️ merged into check-in + standalone client detail table; no standalone server entity |
| SleepStressRecord | ⚠️ merged into SymptomDiary (`sleepInsomnia` is "difficulty falling asleep"); client-side storage only |
| FlareAssessment | ❌ not persisted (computed on the fly by rules); no counterparts for `aiConfidence`, `triggerFactors` |

---

## 4. Non-Functional Requirements

### 4.1 Data Security

> This section was verified line-by-line against the code on 2026-10-26; except for export formats it matches the implementation.

- Patient data encryption: **client-side** local DB SQLCipher (AES-256) + cloud backup AES-GCM end-to-end ciphertext (server stores only ciphertext, cannot decrypt) ✅ **true** (mobile App only; PC Web stores data in plaintext localStorage — sensitive operations should go through the App); server-side parse/sync staging data is currently **stored in plaintext** ✅ true (parse jobs and business CRUD are plaintext; the ciphertext snapshot channel excepted); field-level encryption (AES-256-GCM DEK) is target design, not yet implemented ✅ true (encryption functions exist on the client but have no callers; the `wrappedDek` re-wrapping for doctor authorization excepted)
- Local-first storage, cloud sync optional ✅ (cloud sync is a manually triggered end-to-end ciphertext snapshot; see §4.2.7)
- **"Delete-after-use"** ➕: after parse confirmation the cloud PDF original is deleted by default (idempotent, a dedicated delete endpoint + `sourceDeleted` state); note "delete-after-use" covers only the original file — the parsed structured data is retained as business needs require
- Data export support — ⚠️ **actually JSON / CSV / Excel(xlsx) + browser printing** (App: multi-table CSV + JSON backup; Web: JSON/CSV/Excel + print view); **PDF file generation and DOCX are not implemented** (the V1.0 wording "JSON/PDF/DOCX" was untrue and has been corrected; the print view can be saved as PDF by the user)
- Privacy design aligns with the medical-data principles of China's Personal Information Protection Law (PIPL) (local-first, minimal upload, explicit consent); DPIA and informed-consent **templates are now in `docs/compliance/` (T7)**, while the **formal compliance texts still await legal sign-off** (the templates carry their own ⛔ markers); the non-diagnostic/non-therapeutic disclaimer is persistently visible on 5 interpretation pages (T7); see `docs/security-checklist.md` for the production security checklist
- ➕ Security hardening (implemented items not recorded in the PRD): CORS allow-list + Swagger disabled in production; multi-layer rate limiting on login/upload/sessions/authorization codes + XFF untrusted by default; production config guard; file path-traversal/IDOR protection; Skill regex ReDoS protection; community-publish scrub allow-list; push payloads carry no medical-record information; DPoP-lite device proof-of-possession (server-side core implemented, per-request signature verification pending enablement)

### 4.2 Client-Type Planning

#### 4.2.1 Overall Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Backend service layer              │
│  User mgmt | Data storage | AI parsing engine | Push │
└──────────┬──────────┬──────────┬──────────┬─────────┘
           │          │          │          │
     ┌─────┴───┐ ┌────┴────┐ ┌──┴──┐ ┌────┴────┐
     │ Mobile  │ │ WeChat  │ │ PC  │ │ Doctor  │
     │ App     │ │ Mini    │ │ Web │ │ Web     │
     │ (core)  │ │ Program │ │     │ │         │
     └─────────┘ └─────────┘ └─────┘ └─────────┘
```

> **Implementation status (2026-10-26) ✅**: All four clients have landed — Mobile App (Flutter), WeChat Mini Program (Taro 3.6 + React, 5 pages), PC Web (React 18 + Vite + ECharts), Doctor Web (standalone Vite React app).

#### 4.2.2 Mobile App (Android + iOS) — Primary Client

**Positioning**: The core platform for patients' daily use, carrying high-frequency interaction scenarios

**Features suited to the App** (✅ largely complete; sleep/stress merged into the daily check-in):

| Feature module | Reason | Status |
|----------------|--------|--------|
| Daily symptom diary | High-frequency operations, need to record anytime | ✅ (bloating missing; see §2.7.1) |
| Bowel movement records | Immediate need, on-the-spot reporting | ✅ |
| Injection/medication reminders | Requires system-level push notifications | ⚠️ injection = local notifications; medication reminders missing |
| Flare warning | Real-time assessment combining symptom data | ✅ (rules-based) |
| PDF photo upload | Uses the phone camera | ⚠️ actually a file picker (pdf/txt/png/jpg), **no camera photo capture yet** |
| Injection schedule calendar | Daily viewing | ✅ |
| Sleep/stress records | Daily check-in | ✅ |

**Technical approach** (✅ consistent with the implementation):
- Cross-platform framework: **Flutter** ✅
- Local database: **SQLCipher (sqflite_sqlcipher)**, keys stored in the system Keychain/Keystore ✅
- Push services: local notifications (flutter_local_notifications) ✅ + FCM remote push (optional; credentials pending, real-device verification blocked)
- Camera/gallery: ⚠️ file selection only, camera not connected

**Offline capabilities** (✅):
- Symptom diary and bowel movement records support offline entry; auto-sync when online — ⚠️ offline entry ✅ (local authoritative DB); "auto-sync" is per §4.2.7 (manual ciphertext snapshots)
- Downloaded lab reports can be viewed offline ✅
- Injection/medication reminders do not depend on the network ✅ (local notifications)

#### 4.2.3 WeChat Mini Program — Lightweight Entry

**Positioning**: Lower the barrier to acquisition, provide lightweight services, suitable for users unaccustomed to downloading a standalone app

**Features suited to the Mini Program** (⚠️ deviates from the plan):

| Feature module | Reason | Status |
|----------------|--------|--------|
| Lab report viewing | Convenient viewing of synced data | ✅ (core indicators via API) |
| Injection/recheck reminders | WeChat message push, no extra app needed | ⚠️ subscribe-message template IDs are placeholders (awaiting WeChat appid/template config); the injection page is read-only display |
| Visit summary viewing/sharing | Forward directly to the doctor in WeChat | ✅ (text copy sharing) |
| Symptom diary (simplified) | 1-minute quick check-in | ✅ (abdominal pain / bowel movements + Bristol / overall feeling, local staging) |
| Community interaction | Naturally fits WeChat's social scenarios | ❌ not implemented |
| Skill community browsing | Browse/download parsing templates shared by other users | ❌ not implemented |

**Features NOT suited to the Mini Program**:
- PDF upload & parsing (restricted file operations in Mini Programs) — ✅ indeed not implemented
- Complex trend charts (screen and interaction limitations) — ⚠️ actually a value list, no charts
- Offline functionality — ⚠️ in reality there is lightweight local staging (check-in writes to local storage); opposite to the V1.0 "does not cache data locally" wording, corrected
- Push reminder reliability is inferior to native apps — ✅ (template messages not yet configured)

**Technical approach** (✅):
- **Taro 3.6 + React** cross-platform framework ✅
- Shares the backend API with the App (`@ibd/api-client`) ✅
- WeChat login is an **optional association** (no login wall) ⚠️ Mini-Program-side WeChat login is only a local flag; backend jscode2session/OAuth is not connected

**Acquisition strategy** (product strategy, not about implementation):
- Mini Program as a **trial entry**, guiding users to download the full app after experiencing core features
- QR-code scanning in hospital settings (e.g., waiting-area QR codes at IBD clinics)
- Share Mini Program cards in patient groups for zero-install spread

#### 4.2.4 PC Web — In-Depth Analysis Platform

**Positioning**: For scenarios requiring in-depth data management and analysis; large screens suit complex operations

**Features suited to Web** (⚠️ deviates from the plan):

| Feature module | Reason | Status |
|----------------|--------|--------|
| Multi-year lab data comparison table | Large tables are easier to browse on PC | ⚠️ data needs JSON import (localStorage), not interoperable with App data |
| Multi-indicator trend charts | Clearer on large screens | ✅ ECharts multi-indicator overlay + time ranges |
| Batch PDF upload & parsing | File operations are more convenient on PC | ✅ real upload chain (presign → upload → parse → confirm → delete-after-use) |
| Surgery record management | Complex forms are more comfortable to fill in | ✅ examination/surgery edit form |
| Annual health report | Full reports are easier to read/export on PC | ❌ not implemented (annual report is App-only) |
| Visit summary editing/export | Smoother editing and PDF export on PC | ⚠️ print view only (data printing), no editor / PDF generation |
| Data export (JSON/Excel) | File handling feels natural on PC | ✅ JSON/CSV/Excel(xlsx) + JSON import for device migration |
| Skill template management | Creating/editing parsing templates needs detailed forms | ✅ `/skills` template CRUD + JSON import/export; `/skill-community` community |

**Technical approach** (✅):
- Frontend: **React 18 + Vite + ECharts** ✅ (Excel export via ExcelJS)
- Responsive design ✅
- Print optimization: browser print view ✅

**Use scenarios**:
- Pre-visit preparation: organize disease-course data on PC, generate a visit summary to print and take to the hospital
- In-depth analysis: compare multi-year lab trends, medication nodes, and indicator changes
- Data management: batch-import historical PDF reports, manually back-fill data

#### 4.2.5 Doctor Web (V2.0) — Doctor-Patient Collaboration

**Positioning**: A dedicated interface for doctors to view patient self-managed data and annotate advice

**Features** (⚠️ backend complete, frontend rather thin):
- View a patient's disease-course data after patient authorization ✅ (minimal disclosure per granted scope: labs / symptoms / alerts / summary)
- View patient symptom diaries and flare warnings ⚠️ symptoms ✅; alerts are simplified rule hints (7-day bloody-stool count)
- Annotate medical advice (e.g., "recommend rechecking calprotectin") ✅ (≤500 characters, persistently stored)
- Sync the disease-course summary during teleconsultations ⚠️ the disease-course summary is generated/copied on demand; no "consultation session" auto-sync
- ➕ Authorization audit logs (view/advice traces), authorization revoke/expiry, visible on the patient side

**Technical approach** (⚠️ differs from the plan):
- Standalone web application with data isolated from the patient side ✅
- Doctor identity authentication — ⚠️ **actually a self-entered practicing license number (optional) + manual admin review**; automatic practicing-license verification is not implemented
- Patient-initiated authorization mechanism (QR code / invitation code) — ⚠️ the **authorization code** (TTL + scope allow-list + rate limiting) is implemented; "QR-code scanning" is not landed on either side (Doctor Web shows a text code, the patient enters it manually); ➕ key handoff via DEK re-wrapping

#### 4.2.6 Client Feature Matrix

> **V1.1 revision**: The table below has been corrected against the actual code support as of 2026-10-26 (about 20 of the 56 cells in the V1.0 matrix did not match the code). Legend: ✅ Core/Full ｜ ⚠️ Simplified/Restricted ｜ ❌ Not supported

| Feature | Mobile App | WeChat Mini Program | PC Web | Doctor Web |
|---------|:---:|:---:|:---:|:---:|
| Daily symptom diary | ✅ Core | ✅ Simplified | ❌ | ✅ View |
| Bowel movement records | ✅ Core | ⚠️ Simplified check-in includes bowel movements | ❌ | ✅ View |
| Injection/medication reminders | ✅ Local notifications | ⚠️ Template pending config | ❌ | ❌ |
| Flare warning | ✅ Rules-based | ❌ | ❌ | ⚠️ Simplified hint |
| PDF upload & parsing | ⚠️ File picker (no photo) | ❌ | ✅ Batch | ❌ |
| Lab data viewing | ✅ | ✅ | ⚠️ Import required | ✅ |
| Trend charts | ⚠️ Single-indicator | ⚠️ Value list | ✅ Full | ❌ |
| Visit summary | ✅ View (no sharing) | ✅ Share | ⚠️ Print | ✅ View |
| Annual report | ✅ Generate + YoY + share | ❌ | ❌ | ❌ |
| Community interaction | ✅ Local peers / medication reviews | ❌ | ❌ | ❌ |
| Skill community | ⚠️ Local cache | ❌ | ✅ Manage + community | ❌ |
| Data export | ✅ CSV/JSON | ❌ | ✅ JSON/CSV/Excel | ⚠️ Copy summary only |
| Surgery records | ✅ View | ❌ | ✅ Edit | ❌ |
| Medication reviews | ✅ | ❌ | ❌ | ❌ |

#### 4.2.7 Cross-Client Data Synchronization

> **V1.1 revision**: The V1.0 description of this section (real-time sync / optimistic locks / cross-client consistency) is target design; the current implementation is a **manual ciphertext snapshot** model and has been corrected accordingly.

**Sync strategy** (⚠️ current state):
- Local authority: the App treats its local SQLCipher DB as the single source of truth; core features have no login wall (`app_user_uuid` local identifier) ✅
- Cloud sync is an **optional, manually triggered** end-to-end ciphertext snapshot (passphrase-derived keys; upload / restore / delete the cloud copy) ⚠️
- The WeChat Mini Program depends mainly on the network; lightweight data such as check-ins has local staging ⚠️
- PC Web and App data are **not interoperable for now** (Web is an independent localStorage data plane; only batch parsing / Skill community go through the server) ❌

**Data consistency** (⚠️ current state vs. target):
- Current state: snapshot-level, higher `version` wins; restore is import-style — restoring repeatedly duplicates data
- Target: record-level timestamp optimistic locking + same-device priority + offline merge queue (**not implemented**)
- The server already has HLC hybrid logical clock fields and `deviceId` markers (reserved for future merging) ➕
- Local-first default: `app_user_uuid`, **no login wall**; core features do not depend on an account ✅
- Cloud capabilities (sync/restore) are optional: link a phone number ✅ (can be unlinked); WeChat OAuth ⚠️ is only a placeholder (local flag), not connected on the backend

#### 4.2.8 Development Priority

| Phase | Client | Timing | Description | Actual status (2026-10-26) |
|-------|--------|--------|-------------|------|
| P0 | Mobile App (Flutter cross-platform) | Alongside MVP | Core product, carrying all high-frequency features | ✅ Delivered |
| P1 | WeChat Mini Program | MVP shell; features can come later | Acquisition entry; MVP prioritizes the App | ✅ Shell + 5 pages delivered |
| P1 | PC Web | V1.0 stage | In-depth analysis and data management | ✅ Delivered (6 pages) |
| P2 | Doctor Web | V2.0 stage | Doctor-patient collaboration | ✅ **Delivered early** (read-only views / advice / audit / revoke) |

### 4.3 Performance Requirements

> ⚠️ **V1.1 revision**: The values below are design targets; there is currently **no SLA/benchmark guarantee**; annotated per actual capability.

- PDF parsing response time < 5 seconds — ⚠️ achievable on the Skill fast lane (pure regex); the AI path depends on the LLM (default timeout 60s), **no <5s guarantee**. Related limits: single file 20MB + PDF magic-number check, ≤4 page images sent to the model, queue concurrency default 2
- Trend chart rendering < 1 second — ⚠️ pure client-side local rendering, usually achievable, no performance-budget tests
- Data sync latency < 3 seconds — ⚠️ request-response sync, no latency guarantee

### 4.4 Usability

> ⚠️ **V1.1 revision**: Two of the three items do not live up to their names.

- Large-font mode (for elderly patients) ✅ 1.25× global text scale
- Simple mode (show only core indicators) ⚠️ currently only hides the home-page privacy banner; no content simplification
- Chinese/English language switching supported ⚠️ the switch and dictionary framework are ready, but **UI copy is not yet wired into the translation pipeline** (the UI is currently hardcoded Chinese); completing i18n coverage is a to-do

---

## 5. Extended Features (V2.0)

> **V1.1 overall revision**: Most capabilities in this chapter were **delivered early** (reconciled 2026-10); each section is annotated with its current state.

### 5.1 Doctor-Patient Collaboration — ⚠️ Partially implemented (backend complete; patient side wired to real APIs)
- After patient authorization, doctors can view patient self-managed data ✅ (authorization code + scope allow-list + minimal disclosure + DEK re-wrapping)
- Doctors can annotate advice ✅; **the patient-side advice/audit/authorization lists are wired to real APIs (T5)**: empty/error states, honest "not synced" markers, and revoke fixed to use the grantId (defect fixed)
- Automatically sync the disease-course summary during teleconsultations ⚠️ generated/copied on demand; no session-level auto-sync
- ➕ Authorization audit logs, revoke/expiry checks, authorization-code rate limiting
- ❌ QR-code authorization (both sides use manual code entry), automatic practicing-license verification

### 5.2 AI-Assisted Analysis — ⚠️ Rules-based version implemented
- Predict disease activity trends based on historical data ❌ not implemented (what exists is trend direction / last-30/90-day mean descriptions)
- Abnormal indicator warnings (e.g., "calprotectin increased twice in a row; recommend seeing a doctor") ⚠️ rules-based: consecutive rises, consecutive bloody stools, sudden bowel-frequency increases, etc.
- Medication efficacy assessment (e.g., "CRP dropped 62% after combination therapy; the regimen is effective") ⚠️ before/after medication mean comparison (text form)
- ➕ Analysis entry page (AI/Rules Analysis); all local pure functions, no cloud models

### 5.3 Parsing Skill Community — ✅ Largely implemented
- User A parses for the first time and confirms → a Skill is auto-generated ✅ (server-side; the App also has a local cache)
- User A chooses to **publish to the community** → other patients at the same hospital can use that Skill directly ✅ (scrub allow-list + value scanning + pseudonymous hash identity; publishes rules only, never raw reports)
- Community Skills have **ratings and reviews** ✅ (one rating per user per template, 1–5 + comment; composite-score ranking)
- When a hospital's format changes, community members collaboratively update the Skill version ⚠️ the collaborative version-bump endpoint exists server-side; **client integration is pending** (repeat publishing of the same hospital+report type auto-bumps the version and works)
- ❌ Contribution points/honor system (only usage counts)
- ✅ Import/export (Web JSON); ✅ Web management entry (`/skills` + `/skill-community`)

**Community value**:
| Participant | Benefit |
|-------------|---------|
| First-time users | No waiting for AI parsing; use the community Skill directly with results in seconds |
| Skill contributors | Contribution points/honor; priority access to high-quality community Skills |
| The community as a whole | The more hospitals covered, the faster new users get started — a network effect |

**Hospital format coverage targets** (product targets; no coverage statistics currently):
- V1.0: Top 50 tertiary hospitals (covering 80%+ of IBD patients)
- V2.0: Top 200 tertiary hospitals
- Long-term: all tertiary hospitals nationwide + major secondary hospitals

### 5.4 Patient Community — ⚠️ Partially implemented
- Anonymous patient communication ⚠️ same-city anonymous posts (pseudonymous; no precise location collected)
- Treatment-regimen experience sharing ⚠️ medication-review community aggregation
- Care guides (IBD specialist information for each hospital) ⚠️ static data for 8 hospitals
- ❌ Local groups, care-process tips, medical insurance policy sharing

### 5.5 Diet Management — ✅ Implemented (partially beyond the PRD)
- IBD-specific recipe recommendations ⚠️ static recipe references (one-tap logging), not personalized recommendations
- Food–symptom correlation records ✅ food-tag meal logs (three meals) + **food × bowel-movement correlation observation analysis** (with lag windows; non-causal, for reference only)
- Nutrient intake tracking ⚠️ rough tracking (calories/protein + last-7-day averages)
- ➕ Food dictionary pickers, nutrition summary bar

---

## 6. Competitive Analysis

| Product | Strengths | Weaknesses |
|---------|-----------|------------|
| DXY Doctor (丁香医生) | Large user base, rich content | No IBD-specific disease-course management |
| WeDoctor (微医) | Convenient online consultation | Fragmented data management |
| MyCrohnsAndColitisTeam | Active IBD community | English-only; no integration with Chinese hospital data |
| Hospital apps | Can view that hospital's reports | Data silos; no cross-hospital integration |

**Differentiated advantages of this product**:
1. **IBD-specific**: Full disease-course management designed for Crohn's disease and ulcerative colitis
2. **Report parsing**: AI + Skill dual-engine auto-parsing of hospital PDF lab reports, improving with use
3. **Injection management**: Biologic-specific injection scheduling and reminder system
4. **Full disease-course view**: A unified timeline of labs + imaging + endoscopy + medications + surgery + symptoms
5. **Visit assistance**: One-click generation of a structured visit summary
6. **Symptom diary**: Complete tracking of daily symptoms + bowel movements + sleep + stress, correlated with lab indicators
7. **Flare warning**: Warning system based on symptom patterns and lab data (currently rules-based; the AI version is a target)

---

## 7. Milestone Plan

> **V1.1 revision**: Most V2.0 content has been delivered early; the table below records the actual status.

| Phase | Duration | Content | Actual status (2026-10-26) |
|-------|----------|---------|------|
| MVP | 2 months | Lab data management (manual entry + PDF parsing) + medication records + injection reminders + **daily symptom diary** | ✅ Complete (symptom diary includes bloating [T1]; injection reminders are local notifications and configurable [T4]) |
| V1.0 | 4 months | + Examination/imaging management + disease-course timeline + trend charts + **bowel movement records** | ✅ Complete (trends/timeline weaker than designed; see §2.1.3/§2.4.1) |
| V1.5 | 6 months | + Visit summary generation + annual report + data export + **flare warning** + **quality-of-life assessment** | ✅ Largely complete (no PDF/DOCX export; warnings are rules-based; SF-36 simplified scoring) |
| V2.0 | 10 months | + Doctor-patient collaboration + AI-assisted analysis + diet management + **medication review community** + **local patient peers** | ✅ **Mostly delivered early** (see Chapter 5); gaps: AI confidence/prediction, QR-code authorization, collaborative versioning UI, community points, local groups |

**Remaining to-dos (by priority; refreshed after P0 sign-off on 2026-10-27)**:
1. Close the real push loop (FCM/vendor-channel verification on real devices) and real-device acceptance — **BLOCKED** (missing credentials/devices)
2. Trend analysis enhancements (multi-indicator overlay / time ranges / medication nodes / threshold lines ported to the App) — P1 T8
3. ~~Complete the reminder system~~ ✅ core delivered (T4/T6); remaining: OBI video, automatic recheck-item suggestions (the latter withheld for compliance)
4. i18n coverage (Chinese/English switching actually applied to the UI), complete Simple mode — P1 T15
5. Timeline enhancements (disease/adverse-reaction events, details, export) and add PDF/DOCX export — P1 T9/T10
6. Cross-client sync upgrades (record-level merging, Web↔App data interoperability) — P1 T16
7. Finish doctor-patient collaboration: ~~patient-side wired to real APIs~~ ✅ (T5); remaining: QR-code authorization, practicing-license verification
8. ~~Fix known defects~~ ✅ **all closed** (bloating/fatigue T1 series, source labels T2, Skill cache T3; P0 acceptance signed off on 2026-10-27)
9. Compliance wrap-up (new): legal sign-off for DPIA/informed-consent (templates in place) + informed-consent touchpoint A (first-launch consent) wiring; SWIPER-R1 runtime verification on real devices (due 2026-11-09)

---

## 8. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Inconsistent hospital PDF formats | Low parsing success rate | Prioritize adapting the Top 10 tertiary hospital formats; open custom templates |
| Low willingness of patients to enter data manually | Incomplete data | Rely mainly on PDF auto-parsing to lower the entry barrier |
| Medical data compliance risk | Legal risk | Local-first data storage; cloud sync requires explicit authorization; supplement DPIA/consent-flow docs |
| Barrier of professional medical terminology | Difficult for users to understand | Provide plain-language explanations (e.g., "calprotectin = the thermometer of gut inflammation") |
| Competitor follow-up | Market competition | Deepen the IBD vertical and build data moats |
| AI parsing accuracy fluctuations | Data quality | User confirmation step + Skill correction feedback + source-label traceability |

---

## 9. Appendix: V1.0 → V1.1 Major Revision List

> Complete evidence (file:line) is in the three audit reports under [var/prd-audit/](../var/prd-audit/).

| # | Section | V1.0 wording | V1.1 correction |
|---|---------|--------------|-----------------|
| 1 | §2.1.1 | Skill template includes `check_fn`, supports cross-line | `check_fn` not implemented (abnormality judged by ref_range); `multiline` stored but not executed |
| 2 | §2.1.1 | Three-way source labels | server-side three-value enum, but confirmation always writes skill and the App has two tiers — distorted (known deviation) |
| 3 | §2.1.3 | Trends: multi-indicator overlay / time ranges / medication nodes / threshold lines / summaries | only PC Web has multi-indicator + time ranges; App has single-indicator lines; nodes/threshold lines/summary text not implemented |
| 4 | §2.2.3 | Induction/maintenance dual frequencies, auto-shift after delays, configurable reminder days | dual frequencies not wired in (protocols defined), no auto-shift, lead days are constants |
| 5 | §2.3 | Full surgery fields + schematics | only 6 entry fields; intraoperative/postoperative scores, attachments, schematics not implemented |
| 6 | §2.4.1 | Timeline year/month zoom, details, PDF export | type filtering only; disease/adverse-reaction events missing; no zoom/details/PDF |
| 7 | §2.5 | Injection/recheck/medication "push reminders" | only injection local notification (single, 3 days ahead); recheck/medication reminders not implemented; FCM pending verification |
| 8 | §2.6.2 | "provisional manual implementation; YoY/summaries pending" note | **note outdated**: auto-build for the most recent complete year + YoY + exam/surgery summaries are implemented |
| 9 | §2.7.1 | Symptom diary includes bloating | bloating not implemented (the bloating column is mistakenly written with the fatigue value — column defect) |
| 10 | §2.7.3 | "AI-assisted judgment" three-level warning | rules-engine three-level warning (AI / historical patterns / fever condition / summary sharing not implemented) |
| 11 | §2.7.4 | SF-36 standard scale | simplified 0–4 scoring + self-computed 8 domain scores (not the original weights/norms) |
| 12 | §3 | LabResult.source two values; FlareAssessment a full entity | source three values; FlareAssessment not persisted, no aiConfidence |
| 13 | §3 | Examination/Surgery server entities | client-side local storage only, no server entity/API |
| 14 | §4.1 | Export JSON/PDF/DOCX | JSON/CSV/Excel + browser printing; PDF generation and DOCX not implemented |
| 15 | §4.2.5 | Doctor "practicing physician license verification", QR-code authorization | self-entered license number + manual review; authorization codes work, QR-code scanning not landed |
| 16 | §4.2.6 | About 20 matrix cells | corrected per actual code (Web lacks diary/bowel/warning/annual report; Doctor Web lacks charts/annual report/export/surgery/medication reviews; App annual report and export are actually ✅) |
| 17 | §4.2.7 | Real-time sync + optimistic locks + cross-client consistency | manual ciphertext snapshots (higher `version` wins); Web↔App not interoperable; WeChat OAuth a placeholder |
| 18 | §4.3 | Performance metrics like parsing <5s | all are unguaranteed target values; AI path default 60s timeout |
| 19 | §4.4 | Simple mode, Chinese/English switching | Simple mode only hides the privacy banner; i18n dictionary ready but UI not wired in |
| 20 | §5 | V2.0 extensions (doctor-patient / AI / community / diet) | mostly delivered early; per-section status detailed in §5.1–5.5 |
| 21 | Whole document | — | ➕ Added notes on capabilities exceeding the PRD: delete-after-use, SF-36 domain-score trends, MiniQoL, food × bowel correlation, medication check-in, audit logs, wrappedDek, DPoP-lite, rate limiting/CORS/scrubbing, etc. |

### V1.1 → V1.2 Revision List (P0 batch T1–T7, 2026-10-27)

| # | Section | V1.1 wording | V1.2 correction |
|---|---------|-------------|-----------------|
| 1 | §2.1.1 | Source labels distorted (to be fixed) | ✅ Fixed (T2): confirm writes `skill\|ai` from the real engine; App writes all three values; old data not back-filled |
| 2 | §2.1.1 | App Skill cache "write-only" | ✅ Closed out (T3): txt fast path / clear / invalidation |
| 3 | §2.2.3/§2.5.1 | Lead days a constant, no config entry | ✅ Multiple configurable lead times (day-of / 1 / 2 / 3 / 7, T4) |
| 4 | §2.5 | Medication / recheck / on-the-day reminders not implemented | ✅ All three delivered (T6: sanitized copy, unified scheduling, backward-compatible defaults) |
| 5 | §2.7.1 | Bloating ❌ (bloating defect to be fixed) | ✅ Implemented (T1); legacy dirty values migrated to NULL with marks (T1.1 ruling-B semantics + compensation script) |
| 6 | §3.2 | source wording too narrow / distorted | ✅ Three values truthful; ➕ ParseJob.engine field (T2, nullable migration) |
| 7 | §4.1 | DPIA/consent docs "not yet provided in this repo" | Templates in `docs/compliance/` (⛔ pending legal sign-off); disclaimer visible on 5 pages; security-checklist (T7) |
| 8 | §5.1 | Patient-side UI is a skeleton (demo data) | ✅ Wired to real APIs (T5): advice/audit/grants lists, revoke fixed, honest degradation |
| 9 | §7 | 8 remaining to-dos | #3/#7/#8 updated to partial/complete; new #9 compliance wrap-up; P0 acceptance signed off 2026-10-27 |

---

> **Document version**: V1.2 (P0-reconciled revision)
> **Revision date**: 2026-10-27
> **Data source**: Designed based on real-world disease-course management experience of a Crohn's disease patient; implementation status comes from code audits (var/prd-audit/) and the P0 acceptance review ([audit-evidence/p0-acceptance-2026-10-27.md](audit-evidence/p0-acceptance-2026-10-27.md), signed off by the user)
> **Reference disease-course span**: Diagnosed 2022.12 → current 2026.09, covering 5 medication regimens, 1 surgery, 44 lab tests, 14 imaging examinations, 2 endoscopies
