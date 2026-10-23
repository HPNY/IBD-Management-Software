# IBD Disease-Course Management Program — Product Requirements Document (PRD)

> Designed based on real-world disease-course management experience of a Crohn's disease patient

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

**Skill template content**:
```yaml
hospital: Tertiary Hospital A
report_type: Complete Blood Count (5-part differential)
version: 1.2
last_updated: YYYY-MM-DD

# Date extraction rules
date_extraction:
  primary: '(\d{8})G\d+'  # Sample number format
  fallback: 'Collection Date:\s*(\d{4})/(\d{1,2})/(\d{1,2})'

# Item extraction rules (same-line and cross-line supported)
items:
  - name: White Blood Cell Count
    alias: WBC
    pattern: 'White Blood Cell Count\s+([\d.]+)'
    multiline: true  # The value may be on the next line
    unit: '10^9/L'
    ref_range: [3.5, 9.5]
    check_fn: 'v < 3.5 or v > 9.5'

  - name: Hemoglobin
    alias: Hb
    pattern: 'Hemoglobin\s+([\d.]+)'
    unit: 'g/L'
    ref_range: [130, 175]
    check_fn: 'v < 130'

  # ... more items

# Special handling rules
special_rules:
  - filter: 'patient_id_mismatch'  # Filter medical-record-number mismatches
    description: 'The medical record number may be matched as a lab value'
    condition: 'value == [medical_record_number]'
    action: 'discard'

  - filter: 'crp_multiline'  # Cross-line handling for CRP
    description: 'The hs-CRP label and its value are often on two lines'
    pattern: 'hs-CRP'
    next_line_pattern: '^([\d.]+)'
    value_filter: '< 100'
```

**Skill template management**:
- Each hospital can have multiple Skills (separated by report type: CBC, liver function, ultrasound, etc.)
- Skills for the same hospital and report type support **version iteration** (auto-updated after user corrections)
- Skills can be **shared** among users (community contributions), reducing the learning cost for new users
- Export/import of Skill templates is supported

##### Engine 2: AI Intelligent Parsing (General Fallback)

**Applicable scenarios**:
- Hospital report formats seen for the first time (no Skill template)
- Image-based/scanned PDFs (OCR + understanding)
- Unusual report formats (e.g., handwriting, non-standard layout)

**AI parsing flow**:

| Step | Handling | Description |
|------|----------|-------------|
| 1. PDF reading | pymupdf | Extract text directly from text-based PDFs; convert image-based PDFs to high-resolution images |
| 2. Text/image understanding | Large language model | Input raw text or images; AI understands the report structure and content |
| 3. Structured extraction | AI + rule validation | Output a standardized JSON structure containing all test items, values, units, and reference ranges |
| 4. Abnormality annotation | Rule engine | Automatically flag ↑/↓ according to reference ranges |
| 5. Result confirmation | User interaction | User confirms/corrects the extraction results |

**AI prompt design example**:
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

**Vision capabilities (image-based PDFs)**:
- For scanned/photographed PDFs, render as high-resolution images (3x zoom)
- Use multimodal LLMs to directly recognize lab data in images
- Support recognition of handwritten annotations (e.g., a doctor's handwritten diagnostic comments)

##### Dual-Engine Collaboration Mechanism

| Scenario | Processing path | Speed | Accuracy |
|----------|----------------|-------|----------|
| Skill template available | Template parsing → output | Extremely fast (<1s) | Extremely high (99%+) |
| First report from this hospital | AI parsing → user confirmation → generate Skill | Slower (3–5s) | High (95%+) |
| Image-based PDF | Vision AI → user confirmation | Slower (5–10s) | Moderately high (90%+) |
| Skill parsing fails | Fall back to AI parsing → update Skill | Medium | High |

**Skill auto-generation/update logic**:
1. User uploads a PDF, no matching Skill → AI parsing → user confirmation → **automatically generate a new Skill**
2. User uploads a PDF, Skill parsing succeeds but misses fields → AI completes → user confirmation → **automatically update the Skill version**
3. User manually corrects AI/Skill parsing results → **feed corrections back into the Skill**, improving next-time accuracy
4. User gets tested at different hospitals → maintain independent Skill libraries per hospital

**Output format**:
- Chinese item names (not English abbreviations)
- Chronologically arranged structured data tables
- Abnormal values marked with ↑↓
- Data source labels (Skill parsing / AI parsing / manual entry)

#### 2.1.2 Manual Entry
**Feature description**: Supports manual entry of lab data, adapted to the following scenarios:
- The report is on paper or an image and cannot be auto-parsed
- Historical data needs to be back-filled
- The patient is tested at different hospitals with inconsistent report formats

**Entry UI design**:
- Grouped by test category (CBC, liver function, inflammatory markers, etc.)
- Each indicator displays its reference range as an input reference
- Entering an out-of-range value automatically prompts ↑ or ↓

#### 2.1.3 Indicator Trend Analysis
**Feature description**: Displays time trends of key indicators in chart form.

**Core IBD indicator panel**:

| Indicator | Reference range | Clinical significance |
|-----------|----------------|----------------------|
| High-sensitivity C-reactive protein (hs-CRP) | <5.0 mg/L | Systemic inflammatory activity |
| Erythrocyte sedimentation rate (ESR) | <15 mm/h | Inflammatory activity (lagging indicator) |
| Fecal calprotectin | <200 μg/g | **Gold standard for intestinal inflammation**, most sensitive |
| Lymphocytes | 1.1–3.2×10⁹/L | Immune status; infection risk under medication |
| Albumin | 40–55 g/L | Nutritional status |
| Hemoglobin | 130–175 g/L | Anemia assessment |
| Uric acid | 208–428 μmol/L | Drug side-effect monitoring |

**Trend analysis features**:
- Customizable time ranges (3 months / 6 months / 1 year / all)
- Multi-indicator overlay comparison (e.g., CRP + calprotectin)
- Mark medication-change nodes (drug switches, dose adjustments) on the chart
- Key threshold lines (e.g., the calprotectin 200 remission line)
- Generate trend summary text (e.g., "CRP dropped steadily from 10.5 to 2.2 — clear improvement")

#### 2.1.4 Examination/Imaging Report Management
**Feature description**: Manages non-lab examination reports (CT, MRI, ultrasound, endoscopy, pathology, etc.).

**Supported examination types**:
- Imaging: CT, MRI, X-ray, ultrasound
- Endoscopy: gastroscopy/colonoscopy reports
- Pathology: biopsy pathology reports
- Special examinations: capsule endoscopy, small-bowel contrast studies, etc.

**Structured storage**:
- Examination date, type, body part
- Key findings (text summary)
- Comparison with previous examinations (e.g., "improved compared with prior")
- Scoring-system records (e.g., SES-CD, Limberg grade, IBUS-SAS score)

---

### 2.2 Medication Management

#### 2.2.1 Current Medication Regimen
**Feature description**: Records all medications currently in use and their detailed information.

**Drug information fields**:

| Field | Description | Example |
|-------|-------------|---------|
| Drug name | Generic + brand name | Upadacitinib (Rinvoq) |
| Drug class | Mechanism-based class | JAK inhibitor |
| Indication | Treatment goal | Crohn's disease maintenance therapy |
| Dose | Single dose | 15 mg |
| Frequency | Dosing frequency | Once every other day |
| Route | Oral/subcutaneous/intravenous | Oral |
| Start date | Date started | [Start date] |
| Status | Active/paused/discontinued | Active |

#### 2.2.2 Medication History Timeline
**Feature description**: A complete record of all previously used medications, dose adjustments, and reasons for discontinuation.

**Recorded dimensions**:
- Medication-switch chain: Humira → Adalimumab (Anjianning) → Upadacitinib 3 tabs → stopped → Upadacitinib 1 tab → stopped → Ustekinumab → Upadacitinib qod → + Risankizumab
- Reason for each adjustment (poor response / side effects / insurance / doctor's advice)
- Side-effect records (shingles, recurrent infections, etc.) and severity
- Duration of discontinuation and recovery process

**Timeline visualization**:
```
2023     2024        2025                    2026
├─Humira─┤─Adalimumab───┤─Upa 3 tabs→stop→1 tab→stop→┤─Upa qod──────→
                                                     └─+Risankizumab─→
                                 ↑shingles       ↑persistent cold
```

#### 2.2.3 Biologic Injection Management
**Feature description**: Injection-schedule management designed specifically for patients on biologics.

**Supported injectable drugs** (extensible):
- Risankizumab (Skyrizi) — IL-23 inhibitor
- Infliximab (Remicade) — TNF-α inhibitor
- Adalimumab (Humira) — TNF-α inhibitor
- Ustekinumab (Stelara) — IL-12/23 inhibitor
- Vedolizumab (Entyvio) — integrin inhibitor

**Injection scheduling features**:
- Automatically generate an injection calendar from the drug regimen
- Distinguish different frequencies for induction vs. maintenance phases
- Reminders X days before injection (configurable, default 3 days)
- Record the actual injection date of each dose (may deviate from plan)
- Automatically adjust subsequent schedules after a delayed injection

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

**Field design**:

| Field | Description |
|-------|-------------|
| Surgery date | Precise to the day |
| Surgery type | Resection / reconstruction / stoma, etc. |
| Operative site | Small bowel / colon / rectum, etc. |
| Intraoperative findings | Lesion description (text + schematic) |
| Procedure | Specific operative description |
| Resected length | Length of bowel resected |
| Anastomosis type | KONO-S / end-to-end / side-to-side, etc. |
| Intraoperative score | e.g., Crohn's disease surgery score |
| Postoperative score | Post-op assessment |
| Surgeon | Name |
| Attachments | Surgery record photos/scans |

#### 2.3.2 Surgical Schematic Management
**Feature description**: Supports uploading intraoperative schematics with annotations of lesion locations and surgical procedures.

- Support uploading surgery record photos (e.g., IBD intraoperative condition schematics)
- Support annotating lesion locations on intestinal anatomy diagrams
- Record total bowel length and remaining length

---

### 2.4 Disease-Course Timeline

#### 2.4.1 Full Disease-Course Timeline
**Feature description**: Integrates all disease-course events into one complete timeline.

**Timeline event types**:
- 🔴 Disease events (diagnosis, relapse, complications)
- 🟡 Examination events (labs, imaging, endoscopy, pathology)
- 💊 Medication events (starting / adjusting / stopping drugs)
- 🏥 Surgery events
- 💉 Injection events
- ⚠️ Adverse-reaction events

**Interaction design**:
- Zoom by year/month
- Filter by event type
- Click an event to view details
- Export to PDF (to show the doctor at visits)

#### 2.4.2 Visit Summary Generation
**Feature description**: Automatically generates a structured visit summary so patients can quickly report their condition to doctors during outpatient visits.

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

#### 2.5.1 Injection Reminders
- Push reminders 3 days and 1 day before injection
- On injection day, remind the patient to bring relevant documents/insurance card
- For subcutaneous drugs, remind the patient to watch the OBI (on-body injector) instructional video

#### 2.5.2 Recheck Reminders
- Automatically suggest recheck timing based on the medication regimen
- Remind about the list of items to be rechecked
- Custom reminders supported

#### 2.5.3 Medication Reminders
- Daily/every-other-day reminders for oral medications
- Record medication adherence

---

### 2.6 Data Visualization

#### 2.6.1 Disease Activity Dashboard
**Feature description**: Combines multiple indicators to display current disease activity.

**Dashboard elements**:
- Inflammatory triad status lights (CRP / ESR / calprotectin)
- Limberg grade trend (ultrasound)
- SES-CD score trend (endoscopy)
- Current medication regimen cards
- Countdown to next injection/recheck

#### 2.6.2 Annual Health Report
**Feature description**: Automatically generates an annual health summary report each year.

> **Implementation status (2026-09)**: Currently a **provisional manual implementation** — users trigger generation and sharing by year on the analysis page; **there is not yet** automatic period-end summarization. Full capabilities (auto-generation, year-over-year comparison, exam/surgery summaries, etc.) are to be completed later according to the original design — see worklist G3.

**Report content**:
- Annual trend of key indicator changes
- Medication adjustment records
- Examination/surgery record summaries
- Comparison with the previous year

---

### 2.7 Symptom and Quality-of-Life Management

> This module draws on the design philosophy of competitors such as MyCrohnsAndColitisTeam and MyGut, filling the gap in the current PRD regarding patients' daily self-management.

#### 2.7.1 Daily Symptom Diary
**Feature description**: Spend 1–2 minutes each day recording the day's symptom status, building longitudinal symptom data.

**Recorded items**:

| Category | Item | Format |
|----------|------|--------|
| Abdominal pain | Severity (0–10) | Slider |
| Diarrhea | Frequency + character (Bristol Stool Form Scale 1–7) | Number + selection |
| Bloody stool | None / mild / obvious | Single select |
| Bloating | Severity (0–10) | Slider |
| Fatigue | Severity (0–10) | Slider |
| Nausea | Yes/No | Toggle |
| Mouth ulcers | Yes/No | Toggle |
| Joint pain | Yes/No + location | Toggle + selection |
| Custom | Patients can add personal items of concern | Text |

**Interaction design**:
- A persistent "Today's check-in" entry on the home page, completable within 1 minute
- Quick templates supported ("same as yesterday" / "better/worse than yesterday")
- Calendar view: color depth indicates symptom severity
- Unrecorded dates shown in gray to encourage continuous logging

#### 2.7.2 Bowel Movement Records
**Feature description**: Fine-grained tracking of bowel movements — the most core daily indicator for IBD patients.

**Recorded items**:
- Time
- Count (daily cumulative)
- Character (Bristol Stool Form Scale, types 1–7)
  - Type 1: hard lumps like nuts
  - Type 4: smooth sausage-shaped (ideal)
  - Type 7: watery
- Urgency (yes/no)
- Blood (none / on wiping / obvious)
- Mucus (yes/no)

**Data value**:
- Correlation analysis with calprotectin, CRP, and other indicators
- Discover food–bowel-movement patterns
- Provide objective data at visits instead of subjective descriptions

#### 2.7.3 Flare Warning (Flare Checker)
**Feature description**: Based on symptom data and historical patterns, assess whether there is a current flare risk.

**Three-level warning mechanism**:

| Level | Trigger condition | Suggestion |
|-------|-------------------|------------|
| 🟢 Normal | Symptom scores stable, bowel movements normal | Continue observation |
| 🟡 Watch | Symptoms worsening for 3 consecutive days, or sudden increase in bowel movements | Suggest rechecking CRP + calprotectin soon |
| 🔴 Alert | Bloody stool, fever >38°C, severe abdominal pain | Seek medical attention immediately |

**AI-assisted judgment**:
- Combine daily symptom data + latest lab indicators + medication status for comprehensive assessment
- Reference pre-flare symptom patterns from history (e.g., "diarrhea worsened 7 days before the last flare")
- Automatically generate a symptom summary when a warning triggers, ready to send to the doctor

#### 2.7.4 Quality-of-Life Assessment
**Feature description**: Regularly assess the overall impact of the disease on quality of life.

**Assessment scales**:
- **SF-36** (general quality-of-life scale) — once a month
- **IBDQ** (IBD-specific quality-of-life scale) — once a quarter
- **PHQ-9** (mental health screening) — once a month

**Application scenarios**:
- Longitudinal tracking of quality-of-life trends
- Assess the overall quality-of-life improvement brought by treatment plans
- Identify mental-health risks (IBD patients have higher depression/anxiety risk than the general population)

#### 2.7.5 Sleep and Stress Tracking
**Feature description**: Sleep quality and psychological stress are important triggers for IBD flares.

**Recorded items**:
- Sleep duration
- Sleep quality (1–5)
- Difficulty falling asleep (yes/no)
- Night wakings (count)
- Stress level (1–10)
- Stress source (work / family / disease / other, optional)

**Data correlation**:
- Analyze delayed correlations such as "high stress → symptoms worsen a few days later"
- Identify patterns between sleep quality and abnormal bowel movements
- Provide patients with quantifiable self-management advice (e.g., "after 3 consecutive nights of <6 hours of sleep, the probability of diarrhea increases 40%")

#### 2.7.6 Medication Reviews
**Feature description**: Patients give subjective reviews of medications they have used, helping fellow patients as a reference.

**Review dimensions**:
- Overall efficacy (1–5 stars)
- Side-effect severity (none / mild / moderate / severe)
- Side-effect types (multi-select: infection, rash, GI reactions, headache, etc.)
- Whether still in use
- Written review (optional)

**Community sharing**:
- Aggregate scores by drug (e.g., "Upadacitinib: 4.2 stars, 328 reviews")
- Filter by IBD type (Crohn's vs. ulcerative colitis)
- Does not replace doctor's advice; for reference only

#### 2.7.7 Local Patient Peers and Care Guides
**Feature description**: Help patients find fellow patients in the same city and quality IBD specialist resources.

**Local patient peers**:
- Match IBD patients in the same city based on geographic location
- Anonymous display (nickname + city, no real names)
- Can form local groups (e.g., "Hangzhou IBD Patient Group")

**Care guides**:
- Recommended IBD specialist hospitals/departments in each city
- Doctors' areas of expertise (e.g., surgical / medical / complex cases)
- Care process tips (registration, examinations, hospitalization experience)
- Sharing of medical insurance policy experience

---

## 3. Data Model

### 3.1 Core Entities

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
└── source: source (PDF parsing / manual entry)

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

---

## 4. Non-Functional Requirements

### 4.1 Data Security
- Encrypted storage of patient health data (AES-256)
- Local storage first, cloud sync optional
- Data export support (JSON/PDF/DOCX formats)
- Compliant with the medical-data provisions of China's Personal Information Protection Law (PIPL)

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

#### 4.2.2 Mobile App (Android + iOS) — Primary Client

**Positioning**: The core platform for patients' daily use, carrying high-frequency interaction scenarios

**Features suited to the App**:

| Feature module | Reason |
|----------------|--------|
| Daily symptom diary | High-frequency operations, need to record anytime |
| Bowel movement records | Immediate need, on-the-spot reporting |
| Injection/medication reminders | Requires system-level push notifications |
| Flare warning | Real-time assessment combining symptom data |
| PDF photo upload | Uses the phone camera |
| Injection schedule calendar | Daily viewing |
| Sleep/stress records | Daily check-in |

**Technical approach**:
- Cross-platform framework: Flutter or React Native (one codebase for both platforms)
- Local database: SQLite/Hive (offline data caching)
- Push services: APNs (iOS) + FCM/vendor push (Android)
- Camera/gallery: PDF photo upload, surgery record scanning

**Offline capabilities**:
- Symptom diary and bowel movement records support offline entry; auto-sync when online
- Downloaded lab reports can be viewed offline
- Injection/medication reminders do not depend on the network

#### 4.2.3 WeChat Mini Program — Lightweight Entry

**Positioning**: Lower the barrier to acquisition, provide lightweight services, suitable for users unaccustomed to downloading a standalone app

**Features suited to the Mini Program**:

| Feature module | Reason |
|----------------|--------|
| Lab report viewing | Convenient viewing of synced data |
| Injection/recheck reminders | WeChat message push, no extra app needed |
| Visit summary viewing/sharing | Forward directly to the doctor in WeChat |
| Symptom diary (simplified) | 1-minute quick check-in |
| Community interaction | Naturally fits WeChat's social scenarios |
| Skill community browsing | Browse/download parsing templates shared by other users |

**Features NOT suited to the Mini Program**:
- PDF upload & parsing (restricted file operations in Mini Programs)
- Complex trend charts (screen and interaction limitations)
- Offline functionality (Mini Programs have no local database)
- Push reminder reliability is inferior to native apps

**Technical approach**:
- Native WeChat Mini Program or Taro/uni-app cross-platform framework
- Shares the backend API with the App
- WeChat login is an **optional association** (no login wall); core browsing/check-in works without login

**Acquisition strategy**:
- Mini Program as a **trial entry**, guiding users to download the full app after experiencing core features
- QR-code scanning in hospital settings (e.g., waiting-area QR codes at IBD clinics)
- Share Mini Program cards in patient groups for zero-install spread

#### 4.2.4 PC Web — In-Depth Analysis Platform

**Positioning**: For scenarios requiring in-depth data management and analysis; large screens suit complex operations

**Features suited to Web**:

| Feature module | Reason |
|----------------|--------|
| Multi-year lab data comparison table | Large tables are easier to browse on PC |
| Multi-indicator trend charts | Clearer on large screens |
| Batch PDF upload & parsing | File operations are more convenient on PC |
| Surgery record management | Complex forms are more comfortable to fill in |
| Annual health report | Full reports are easier to read/export on PC |
| Visit summary editing/export | Smoother editing and PDF export on PC |
| Data export (JSON/Excel) | File handling feels natural on PC |
| Skill template management | Creating/editing parsing templates needs detailed forms |

**Technical approach**:
- Frontend: React or Vue.js + ECharts/D3.js (data visualization)
- Responsive design: adapts to laptop and desktop monitors
- Print optimization: visit summaries and annual reports support browser printing

**Use scenarios**:
- Pre-visit preparation: organize disease-course data on PC, generate a visit summary to print and take to the hospital
- In-depth analysis: compare multi-year lab trends, medication nodes, and indicator changes
- Data management: batch-import historical PDF reports, manually back-fill data

#### 4.2.5 Doctor Web (V2.0) — Doctor-Patient Collaboration

**Positioning**: A dedicated interface for doctors to view patient self-managed data and annotate advice

**Features**:
- View a patient's disease-course data after patient authorization
- View patient symptom diaries and flare warnings
- Annotate medical advice (e.g., "recommend rechecking calprotectin")
- Sync the disease-course summary during teleconsultations

**Technical approach**:
- Standalone web application with data isolated from the patient side
- Doctor identity authentication (practicing physician license verification)
- Patient-initiated authorization mechanism (QR code / invitation code)

#### 4.2.6 Client Feature Matrix

| Feature | Mobile App | WeChat Mini Program | PC Web | Doctor Web |
|---------|:---:|:---:|:---:|:---:|
| Daily symptom diary | ✅ Core | ✅ Simplified | ✅ View | ✅ View |
| Bowel movement records | ✅ Core | ❌ | ✅ View | ✅ View |
| Injection/medication reminders | ✅ Push | ✅ Template messages | ❌ | ❌ |
| Flare warning | ✅ Core | ✅ Notification | ✅ View | ✅ View |
| PDF upload & parsing | ✅ Photo | ❌ | ✅ Batch | ❌ |
| Lab data viewing | ✅ | ✅ | ✅ | ✅ |
| Trend charts | ✅ Basic | ✅ Simplified | ✅ Full | ✅ Full |
| Visit summary | ✅ View | ✅ Share | ✅ Edit & export | ✅ View |
| Annual report | ❌ | ❌ | ✅ Generate & export | ✅ View |
| Community interaction | ✅ | ✅ | ❌ | ❌ |
| Skill community | ✅ | ✅ Browse | ✅ Manage | ❌ |
| Data export | ❌ | ❌ | ✅ | ✅ |
| Surgery records | ✅ View | ❌ | ✅ Edit | ✅ View |
| Medication reviews | ✅ | ✅ | ❌ | ✅ View |

#### 4.2.7 Cross-Client Data Synchronization

**Sync strategy**:
- Core data (symptoms, bowel movements, labs) syncs in real time via the cloud
- The mobile app supports offline operations and auto-merges when online
- The WeChat Mini Program depends on the network and does not cache data locally
- PC Web and the App are consistent in real time (same backend API)

**Data consistency**:
- Timestamp-based optimistic-lock conflict resolution
- Same device takes priority (e.g., a symptom diary entered on the phone is not overwritten by the PC)
- Local-first default: `app_user_uuid`, **no login wall**; core features do not depend on an account
- Cloud capabilities (sync/restore) are optional: link a phone number or WeChat OAuth (no forced login); after linking, the account can be unlinked without affecting local data

#### 4.2.8 Development Priority

| Phase | Client | Timing | Description |
|-------|--------|--------|-------------|
| P0 | Mobile App (Flutter cross-platform) | Alongside MVP | Core product, carrying all high-frequency features |
| P1 | WeChat Mini Program | MVP shell; features can come later | Acquisition entry; MVP prioritizes the App; Mini Program scaffold/four pages can run in parallel with MVP; login/subscribe messages and other dependencies on external credentials may come late |
| P1 | PC Web | V1.0 stage | In-depth analysis and data management |
| P2 | Doctor Web | V2.0 stage | Doctor-patient collaboration |

### 4.3 Performance Requirements
- PDF parsing response time < 5 seconds
- Trend chart rendering < 1 second
- Data sync latency < 3 seconds

### 4.4 Usability
- Large-font mode (for elderly patients)
- Simple mode (show only core indicators)
- Chinese/English language switching supported

---

## 5. Extended Features (V2.0)

### 5.1 Doctor-Patient Collaboration
- After patient authorization, doctors can view patient self-managed data
- Doctors can annotate advice (e.g., "recommend rechecking calprotectin next time")
- Automatically sync the disease-course summary during teleconsultations

### 5.2 AI-Assisted Analysis
- Predict disease activity trends based on historical data
- Abnormal indicator warnings (e.g., "calprotectin increased twice in a row; recommend seeing a doctor")
- Medication efficacy assessment (e.g., "CRP dropped 62% after combination therapy; the regimen is effective")

### 5.3 Parsing Skill Community

**Core idea**: The hospital report formats parsed by each patient can be contributed to the community, so other patients at the same hospital can use them directly without learning from scratch.

**Feature design**:
- User A parses "Tertiary Hospital A CBC" for the first time and confirms → a Skill is auto-generated
- User A chooses to **publish to the community** → other Tertiary Hospital A patients can use that Skill directly
- Community Skills have **ratings and reviews** to surface the highest-accuracy templates
- When a hospital's format changes (e.g., system upgrade), community members can collaboratively update the Skill version

**Community value**:
| Participant | Benefit |
|-------------|---------|
| First-time users | No waiting for AI parsing; use the community Skill directly with results in seconds |
| Skill contributors | Contribution points/honor; priority access to high-quality community Skills |
| The community as a whole | The more hospitals covered, the faster new users get started — a network effect |

**Hospital format coverage targets**:
- V1.0: Top 50 tertiary hospitals (covering 80%+ of IBD patients)
- V2.0: Top 200 tertiary hospitals
- Long-term: all tertiary hospitals nationwide + major secondary hospitals

### 5.4 Patient Community
- Anonymous patient communication
- Treatment-regimen experience sharing
- Care guides (IBD specialist information for each hospital)

### 5.5 Diet Management
- IBD-specific recipe recommendations
- Food–symptom correlation records
- Nutrient intake tracking

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
7. **Flare warning**: AI warning system based on symptom patterns and lab data

---

## 7. Milestone Plan

| Phase | Duration | Content |
|-------|----------|---------|
| MVP | 2 months | Lab data management (manual entry + PDF parsing) + medication records + injection reminders + **daily symptom diary** |
| V1.0 | 4 months | + Examination/imaging management + disease-course timeline + trend charts + **bowel movement records** |
| V1.5 | 6 months | + Visit summary generation + annual report + data export + **flare warning** + **quality-of-life assessment** |
| V2.0 | 10 months | + Doctor-patient collaboration + AI-assisted analysis + diet management + **medication review community** + **local patient peers** |

---

## 8. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Inconsistent hospital PDF formats | Low parsing success rate | Prioritize adapting the Top 10 tertiary hospital formats; open custom templates |
| Low willingness of patients to enter data manually | Incomplete data | Rely mainly on PDF auto-parsing to lower the entry barrier |
| Medical data compliance risk | Legal risk | Local-first data storage; cloud sync requires explicit authorization |
| Barrier of professional medical terminology | Difficult for users to understand | Provide plain-language explanations (e.g., "calprotectin = the thermometer of gut inflammation") |
| Competitor follow-up | Market competition | Deepen the IBD vertical and build data moats |

---

> **Document version**: V1.0
> **Generation date**: 2026-09-11
> **Data source**: Designed based on real-world disease-course management experience of a Crohn's disease patient
> **Reference disease-course span**: Diagnosed 2022.12 → current 2026.09, covering 5 medication regimens, 1 surgery, 44 lab tests, 14 imaging examinations, 2 endoscopies
