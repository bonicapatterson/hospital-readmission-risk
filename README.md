# 🏥 Hospital Readmission Risk Analysis

<div align="center">

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Cloud-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Tableau](https://img.shields.io/badge/Tableau-Public-E97627?style=for-the-badge&logo=tableau&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-4479A1?style=for-the-badge&logo=databricks&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-Portfolio-181717?style=for-the-badge&logo=github&logoColor=white)

**A production-grade clinical analytics pipeline examining 30-day hospital readmission risk**

*Built with PostgreSQL · Supabase · Tableau Public · Advanced SQL*

### 📊 [View Live Interactive Story Dashboard →](https://public.tableau.com/app/profile/bonica.patterson/viz/ReAdmission-Workbook/Story1?publish=yes)

</div>

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Business Problem](#-business-problem)
- [Dataset & Schema](#-dataset--schema)
- [SQL Techniques Demonstrated](#-sql-techniques-demonstrated)
- [Key Findings](#-key-findings)
- [Risk Scoring Model](#-risk-scoring-model)
- [Tableau Story Dashboard](#-tableau-story-dashboard)
- [Repository Structure](#-repository-structure)
- [Skills Demonstrated](#-skills-demonstrated)
- [How to Reproduce](#-how-to-reproduce)

---

## 🎯 Project Overview

This end-to-end analytics project simulates a real-world clinical data workflow — from raw database design through advanced SQL analysis to executive-level visualization. The goal: **identify which patients are most at risk of being readmitted to hospital within 30 days of discharge** — a critical quality metric in healthcare that directly impacts patient outcomes and hospital costs.

| Metric | Value |
|--------|-------|
| 👥 Total Patients | 520 |
| 🏥 Total Admissions | 2,020 |
| 🔬 Lab Results | 6,015 |
| 💊 Procedures | 3,041 |
| 🩺 Diagnoses | 3,972 |
| 📅 Date Range | 2019 – 2025 |
| ⚠️ 30-Day Readmission Rate | **16.0%** |
| 🔴 High Risk Admissions | **23%** of cohort |

> **Dataset Note:** This project uses a synthetic dataset modelled on the structure of [MIMIC-III](https://mimic.mit.edu/), a real-world de-identified clinical database from Beth Israel Deaconess Medical Center. All patient data is artificially generated.

---

## 🚨 Business Problem

Hospital readmissions within 30 days represent one of the most expensive and preventable problems in modern healthcare. In the United States alone, readmissions cost the system over **$26 billion annually**. Hospitals face financial penalties under CMS (Centers for Medicare & Medicaid Services) programs for excess readmissions in conditions like heart failure, pneumonia, and COPD.

**This project answers five core questions:**

1. Which diagnoses have the highest 30-day readmission rates?
2. What patient characteristics — age, length of stay, prior admissions, lab abnormalities — predict readmission?
3. Can a multi-factor risk score identify high-risk patients *before* discharge?
4. Where do readmissions cluster across admission types and diagnoses?
5. Are there temporal patterns in readmission that suggest systemic or seasonal causes?

---

## 🗄️ Dataset & Schema

The database consists of **5 normalized clinical tables** designed to mirror real hospital EHR (Electronic Health Record) data structures.

```
┌─────────────┐       ┌────────────────────┐         ┌───────────────────┐
│  patients   │──────▶│   admissions       │────────▶│   diagnoses       │
│─────────────│  1:N  │────────────────────│    1:N  │───────────────────│
│ patient_id  │       │ admission_id       │         │ diagnosis_id      │
│ gender      │       │ patient_id (FK)    │         │ admission_id (FK) │
│ dob         │       │ admit_time         │         │ icd9_code         │
│ ethnicity   │       │ discharge_time     │         │ description       │
└─────────────┘       │ admission_type     │         └───────────────────┘
                      │ discharge_location │
                      │ insurance          │         ┌───────────────────┐
                      │ diagnosis          │────────▶│   procedures      │
                      └────────────────────┘    1:N  │───────────────────│
                               │                     │ procedure_id      │
                               │ 1:N                 │ admission_id (FK) │
                               ▼                     │ icd9_code         │
                      ┌────────────────────┐         │ description       │
                      │   lab_results      │         └───────────────────┘
                      │────────────────────│
                      │ lab_id             │
                      │ admission_id (FK)  │
                      │ test_name          │
                      │ value              │
                      │ unit               │
                      │ flag               │
                      └────────────────────┘



## 🛠️ SQL Techniques Demonstrated

### 1. 30-Day Readmission Detection — `03_30day_readmissions.sql`

Self JOIN to find patients who returned within 30 days of a prior discharge:

```sql
SELECT
    a1.admission_id AS original_admission,
    a2.admission_id AS readmission,
    a1.patient_id,
    EXTRACT(DAY FROM a2.admit_time - a1.discharge_time) AS days_between
FROM admissions a1
JOIN admissions a2
    ON a1.patient_id = a2.patient_id
    AND a2.admit_time > a1.discharge_time
    AND a2.admit_time <= a1.discharge_time + INTERVAL '30 days'
    AND a1.admission_id != a2.admission_id;
```

> **Result:** 164 readmission events identified across 2,020 admissions.

---

### 2. Readmission Rate by Diagnosis — `04_readmission_by_diagnosis.sql`

Multi-table JOIN with aggregation and `NULLIF` to prevent division-by-zero errors. Produces per-diagnosis readmission rates ranked highest to lowest.

**Top Results:**

| Diagnosis | Admissions | Readmissions | Rate |
|-----------|-----------|--------------|------|
| Type 2 Diabetes Mellitus | 8 | 8 | **100%** |
| Stroke | 11 | 11 | **100%** |
| Acute MI | 9 | 9 | **100%** |
| Hip Fracture | 10 | 6 | 60% |
| Renal Failure | 12 | 6 | 50% |
| Tobacco Use Disorder | 7 | 3 | 43% |
| Breast Cancer | 16 | 4 | 25% |

---

### 3. Patient Summary with Chained CTEs — `05_patient_cte_summary.sql`

Five CTEs chained sequentially to build a complete patient-level summary with readmission flags, average length of stay, and emergency admission counts:

```sql
WITH admission_counts AS (...),
     readmission_flags AS (...),
     lab_summaries AS (...),
     risk_indicators AS (...),
     final_summary AS (...)
SELECT * FROM final_summary ORDER BY total_admissions DESC;
```

> **Result:** 473-row patient summary with YES/NO readmission flags and full clinical context.

---

### 4. Window Functions — `06_window_functions.sql`

Analytical window functions for admission sequencing and gap analysis:

```sql
ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY admit_time)  -- Admission sequence
LAG(admit_time)  OVER (PARTITION BY patient_id ORDER BY admit_time)  -- Previous admission
LEAD(admit_time) OVER (PARTITION BY patient_id ORDER BY admit_time)  -- Next admission
```

---

### 5. Multi-Factor Risk Scoring Model — `07_risk_scoring_model.sql`

The most complex query in the project. Five chained CTEs feed a CASE-based weighted scoring algorithm that assigns every admission a clinical risk category at discharge:

```
Risk Factor                              Weight
────────────────────────────────────────────────
Age ≥ 65                                  +2
Length of Stay ≥ 7 days                   +2
Emergency admission type                  +2
2 or more prior admissions                +3
2 or more abnormal lab results            +2
SNF or Home Health discharge location     +1

Thresholds
────────────────────────────────────────────────
HIGH    Total score ≥ 8
MEDIUM  Total score 4 – 7
LOW     Total score < 4
```

> **Result:** HIGH 23% · MEDIUM 63% · LOW 14% across 2,020 admissions.

---

### 6. Performance Indexing — `08_indexes.sql`

Strategic index creation on high-cardinality foreign key columns to optimize JOIN performance at scale:

```sql
CREATE INDEX idx_admissions_patient_id     ON admissions(patient_id);
CREATE INDEX idx_admissions_admit_time     ON admissions(admit_time);
CREATE INDEX idx_lab_results_admission_id  ON lab_results(admission_id);
CREATE INDEX idx_diagnoses_admission_id    ON diagnoses(admission_id);
CREATE INDEX idx_admissions_patient_admit  ON admissions(patient_id, admit_time);
```

---

## 🔍 Key Findings

### 1. Chronic Conditions Have 100% Readmission Rates
Type 2 Diabetes, Stroke, and Acute MI patients returned within 30 days at a 100% rate. This is not a data anomaly — it reflects the real-world reality that these conditions require ongoing management that the current discharge process fails to provide.

### 2. 23% of Admissions Are HIGH Risk
Nearly 1 in 4 admissions scores HIGH risk under the scoring model. These patients need same-day discharge planning with scheduled 7-day follow-up as standard protocol, not a best-effort.

### 3. Comorbidities Drive Risk More Than Age
The scatter analysis shows HIGH-risk patients trend toward *shorter* hospital stays with increasing age — younger high-risk patients have longer stays. This is the opposite of what one might expect, and it suggests clinical complexity and multi-system disease, not age alone, is the dominant readmission driver.

### 4. Pathway-Specific Hotspots Exist
The heatmap reveals that **ELECTIVE Hip Fracture** and **URGENT Tobacco Use Disorder** admissions show the darkest cells — these specific diagnosis-pathway combinations are the highest-concentration readmission hotspots and the strongest candidates for targeted care protocol redesign.

### 5. A 2022–2023 Readmission Spike
Monthly readmissions peak sharply in 2022–2023, concentrated in HIGH and MEDIUM risk patients. This temporal clustering warrants further investigation — potential causes include post-pandemic discharge pressure, staffing shortfalls, or changes in patient acuity.

---

## 📊 Tableau Story Dashboard

An 8-page interactive Tableau Story walks through the complete analysis as a data-driven narrative:

| # | Page Title | Visualization |
|---|-----------|--------------|
| 1 | Overview | KPI cards — patients, admissions, readmission rate, high risk count |
| 2 | The Problem: Which Diagnoses Drive Readmissions? | Ranked horizontal bar chart |
| 3 | Who's At Risk? | Pie chart with risk distribution |
| 4 | Clinical Patterns | Scatter plot — age vs. LOS, coloured by risk, with trend lines |
| 5 | Where Readmissions Happen | Heatmap — diagnosis × admission type |
| 6 | Readmission Trend | Multi-line time series by risk category |
| 7 | Recommendations | Five actionable clinical recommendations |
| 8 | Thank You | Project closing with tech stack and links |

**Design System**

| Element | Color |
|---------|-------|
| Background | `#F7F9FC` |
| Header / Navy | `#0A2342` |
| Primary Blue | `#1D6FA4` |
| HIGH Risk | `#C0392B` |
| MEDIUM Risk | `#E67E22` |
| LOW Risk | `#1A936F` |

### 🔗 [Launch Interactive Dashboard →](https://public.tableau.com/app/profile/bonica.patterson/viz/ReAdmission-Workbook/Story1?publish=yes)

---

## 📁 Repository Structure

```
hospital-readmission-risk/
│
├── README.md
│
├── 01_create_tables.sql           ← Schema: 5 normalized clinical tables
├── 02_seed_data.sql               ← Synthetic data: 520 patients, 2,020 admissions
├── 03_30day_readmissions.sql      ← Self JOIN — 164 readmission events detected
├── 04_readmission_by_diagnosis.sql← Per-diagnosis readmission rates
├── 05_patient_cte_summary.sql     ← 5 chained CTEs — patient-level summary
├── 06_window_functions.sql        ← ROW_NUMBER, LAG, LEAD, PARTITION BY
├── 07_risk_scoring_model.sql      ← Multi-factor weighted risk score
└── 08_indexes.sql                 ← 5 performance indexes
```

---

## 💡 Skills Demonstrated

| Category | Details |
|----------|---------|
| **Database Design** | Normalized schema, ERD modelling, PKs/FKs, referential integrity |
| **SQL Foundations** | SELECT, WHERE, GROUP BY, ORDER BY, HAVING, DISTINCT, LIMIT |
| **SQL Intermediate** | JOINs (INNER, LEFT, SELF), subqueries, CASE expressions, date arithmetic, NULLIF |
| **SQL Advanced** | Chained CTEs, window functions (ROW_NUMBER, LAG, LEAD, PARTITION BY), aggregation pipelines |
| **Performance** | Strategic indexing on FK columns, composite indexes |
| **Data Visualization** | Tableau calculated fields, custom color palettes, pie/bar/scatter/heatmap/line charts, story points, dashboard layout design |
| **Clinical Domain** | ICD-9 coding, 30-day readmission metrics, risk stratification methodology, LOS analysis |
| **Tools & Stack** | PostgreSQL 16, Supabase, Tableau Desktop Public Edition, Git, GitHub |

---

## ▶️ How to Reproduce

### Prerequisites
- [Supabase account](https://supabase.com) (free tier sufficient)
- [Tableau Desktop Public Edition](https://www.tableau.com/products/public/download) (free)

### Steps

**1. Clone the repository**
```bash
git clone https://github.com/bonicapatterson/hospital-readmission-risk.git
cd hospital-readmission-risk
```

**2. Set up the database**
- Create a new project in [Supabase](https://supabase.com)
- Open the SQL Editor in your Supabase dashboard
- Run scripts in order:
  ```
  01_create_tables.sql  →  02_seed_data.sql  →  08_indexes.sql
  ```

**3. Run the analysis queries**
- Run `03_30day_readmissions.sql` through `07_risk_scoring_model.sql` in Supabase SQL Editor
- Export the risk scoring output as `readmission_data.csv` for Tableau

**4. Explore the dashboard**
- Visit the [live Tableau Story](https://public.tableau.com/app/profile/bonica.patterson/viz/ReAdmission-Workbook/Story1?publish=yes) directly
- Or download the workbook from Tableau Public and open in Tableau Desktop Public Edition

---

## 👩‍💻 About

**Bonica Patterson** — Data Analyst with a focus on healthcare analytics, SQL, and data storytelling.

📁 [GitHub Portfolio](https://github.com/bonicapatterson) &nbsp;·&nbsp; 📊 [Tableau Public](https://public.tableau.com/app/profile/bonica.patterson)

---

<div align="center">

*Built end-to-end with PostgreSQL, Supabase, Tableau, and a lot of CTEs.*

</div>
