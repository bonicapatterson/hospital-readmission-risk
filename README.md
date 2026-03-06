# 🏥 Hospital Readmission Risk Analysis
### A Healthcare Analytics SQL Project | PostgreSQL · Supabase

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue?logo=postgresql&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-hosted-3ECF8E?logo=supabase&logoColor=white)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Domain](https://img.shields.io/badge/Domain-Healthcare%20Analytics-red)

---

## 📌 Project Overview

This project simulates a real-world **hospital readmission risk analysis system** built entirely in SQL. Using a synthetic inpatient clinical dataset modelled after the structure of the MIMIC-III clinical database, the project identifies patients at high risk of readmission within 30 days of discharge — one of the most important metrics in healthcare quality measurement and a key focus of the U.S. Centers for Medicare & Medicaid Services (CMS).

The project demonstrates production-level SQL skills including schema design, multi-table joins, CTEs, window functions, and a multi-factor risk scoring model.

---

## 🗄️ Database Schema

The database consists of 5 related tables totalling **15,000+ rows** of synthetic clinical data:

```
patients        (520 rows)   — Demographics: gender, DOB, ethnicity
admissions    (2,020 rows)   — Visit records: admit/discharge times, diagnosis, insurance
diagnoses     (3,972 rows)   — ICD-9 codes per admission
procedures    (3,041 rows)   — Clinical procedures performed
lab_results   (6,015 rows)   — Lab test results with abnormal flags
```

### Entity Relationship Diagram

```
patients
   │
   └──< admissions
              │
              ├──< diagnoses
              ├──< procedures
              └──< lab_results
```

---

## 🔍 Queries & Analysis

### 1. 30-Day Readmission Detection
**Technique:** Self JOIN on the admissions table  
Identifies patients who returned within 30 days of discharge by joining the admissions table against itself, matching on patient ID with a time window constraint.

```sql
SELECT
    a1.patient_id,
    a1.admission_id        AS first_admission_id,
    a1.discharge_time      AS first_discharge,
    a2.admission_id        AS readmission_id,
    a2.admit_time          AS readmission_date,
    DATE_PART('day', a2.admit_time - a1.discharge_time) AS days_until_readmission
FROM admissions a1
JOIN admissions a2
    ON a1.patient_id = a2.patient_id
    AND a2.admit_time > a1.discharge_time
    AND a2.admit_time <= a1.discharge_time + INTERVAL '30 days'
ORDER BY days_until_readmission ASC;
```
**Result:** 164 readmission events identified across the dataset.

---

### 2. Readmission Rate by Diagnosis
**Technique:** LEFT JOIN + GROUP BY + NULLIF division guard  
Calculates the 30-day readmission rate per diagnosis, including diagnoses with zero readmissions.

**Key findings:**
| Diagnosis | Patients | Readmissions | Rate |
|---|---|---|---|
| Breast cancer | 57 | 11 | 19.3% |
| Asthma unspecified | 65 | 9 | 13.8% |
| Diabetic ketoacidosis | 73 | 10 | 13.7% |
| Pneumonia | 66 | 9 | 13.6% |

---

### 3. Patient Admission History (CTE)
**Technique:** Chained CTEs (WITH clauses)  
Two CTEs work together — the first summarises each patient's full admission history, the second flags patients with a 30-day readmission — then they are joined in the final SELECT.

```sql
WITH admission_summary AS (
    SELECT patient_id,
           COUNT(*)                    AS total_admissions,
           MIN(admit_time)             AS first_admission,
           MAX(admit_time)             AS latest_admission,
           ROUND(AVG(EXTRACT(EPOCH FROM
               (discharge_time - admit_time))/86400)::NUMERIC, 1)
                                       AS avg_length_of_stay_days,
           SUM(CASE WHEN admission_type = 'EMERGENCY'
               THEN 1 ELSE 0 END)      AS emergency_count
    FROM admissions
    GROUP BY patient_id
),
readmission_flags AS (
    SELECT DISTINCT a1.patient_id
    FROM admissions a1
    JOIN admissions a2
        ON a1.patient_id = a2.patient_id
        AND a2.admit_time > a1.discharge_time
        AND a2.admit_time <= a1.discharge_time + INTERVAL '30 days'
)
SELECT s.*,
       CASE WHEN r.patient_id IS NOT NULL
           THEN 'YES' ELSE 'NO' END    AS readmitted_within_30_days
FROM admission_summary s
LEFT JOIN readmission_flags r ON s.patient_id = r.patient_id
ORDER BY total_admissions DESC;
```

---

### 4. Admission Sequencing with Window Functions
**Technique:** ROW_NUMBER, LAG, LEAD, PARTITION BY  
Sequences every patient's admissions chronologically and surfaces the previous/next diagnosis and days between visits for each row.

```sql
SELECT
    patient_id,
    admission_id,
    diagnosis,
    ROW_NUMBER() OVER (
        PARTITION BY patient_id ORDER BY admit_time
    )                                           AS admission_number,
    LAG(diagnosis)  OVER (
        PARTITION BY patient_id ORDER BY admit_time
    )                                           AS previous_diagnosis,
    LEAD(diagnosis) OVER (
        PARTITION BY patient_id ORDER BY admit_time
    )                                           AS next_diagnosis,
    ROUND(DATE_PART('day',
        admit_time - LAG(discharge_time) OVER (
            PARTITION BY patient_id ORDER BY admit_time
        ))::NUMERIC, 0)                         AS days_since_last_discharge
FROM admissions
ORDER BY patient_id, admit_time;
```

---

### 5. 🎯 Readmission Risk Scoring Model
**Technique:** Multi-CTE pipeline + CASE-based scoring + risk stratification  
The centrepiece of the project. Assigns every admission a numeric risk score based on six clinical risk factors, then classifies each as HIGH / MEDIUM / LOW risk.

**Scoring criteria:**
| Risk Factor | Points |
|---|---|
| Age ≥ 65 | +2 |
| Length of stay ≥ 7 days | +2 |
| Emergency admission | +2 |
| 2+ prior admissions | +3 |
| 2+ abnormal lab results | +2 |
| Discharged to SNF or Home Health Care | +1 |

**Risk bands:**
- 🔴 **HIGH** — Score ≥ 8
- 🟡 **MEDIUM** — Score 4–7
- 🟢 **LOW** — Score < 4

**Sample HIGH risk patients:**
| Patient | Diagnosis | Age | LOS | Prior Admits | Score |
|---|---|---|---|---|---|
| 472 | Acute renal failure | 72 | 12.1 days | 5 | 12 |
| 373 | Acute myocardial infarction | 93 | 7.1 days | 6 | 12 |
| 134 | Ischemic stroke | 82 | 19.3 days | 2 | 12 |

---

## ⚡ Performance Optimisation

Five indexes were created to optimise the most expensive query patterns:

```sql
-- Patient lookup in admissions (used in every JOIN)
CREATE INDEX idx_admissions_patient_id ON admissions(patient_id);

-- Date range scans (core of 30-day window logic)
CREATE INDEX idx_admissions_admit_time ON admissions(admit_time);

-- Lab result lookups by admission
CREATE INDEX idx_lab_results_admission_id ON lab_results(admission_id);

-- Diagnosis filtering
CREATE INDEX idx_diagnoses_admission_id ON diagnoses(admission_id);

-- Composite index for the self-join pattern
CREATE INDEX idx_admissions_patient_admit ON admissions(patient_id, admit_time);
```

---

## 🛠️ Tech Stack

| Tool | Purpose |
|---|---|
| **PostgreSQL** | Database engine |
| **Supabase** | Cloud hosting & SQL editor |
| **SQL** | 100% of the analysis — no Python, no BI tools |

---

## 💡 Skills Demonstrated

- ✅ Schema design with foreign key constraints
- ✅ INNER, LEFT, and SELF JOINs
- ✅ Aggregations with GROUP BY and HAVING
- ✅ Common Table Expressions (CTEs) — chained multi-step logic
- ✅ Window functions — ROW_NUMBER, LAG, LEAD, PARTITION BY
- ✅ CASE-based conditional logic and risk scoring
- ✅ Date/time arithmetic with INTERVAL and EXTRACT
- ✅ NULLIF for safe division
- ✅ Index creation for query optimisation
- ✅ Synthetic dataset design modelled on MIMIC-III schema

---

## 📁 Repository Structure

```
hospital-readmission-risk/
│
├── schema/
│   └── 01_create_tables.sql        # Table definitions + constraints
│
├── data/
│   └── 02_seed_data.sql            # Synthetic patient dataset
│
├── queries/
│   ├── 03_30day_readmissions.sql   # Self JOIN readmission detection
│   ├── 04_readmission_by_diagnosis.sql
│   ├── 05_patient_cte_summary.sql  # Chained CTEs
│   ├── 06_window_functions.sql     # ROW_NUMBER, LAG, LEAD
│   └── 07_risk_scoring_model.sql   # Full risk stratification model
│
├── optimisation/
│   └── 08_indexes.sql              # Performance indexes
│
└── README.md
```

---

## 🚀 How to Run

1. Create a free project at [supabase.com](https://supabase.com)
2. Open the **SQL Editor**
3. Run files in order: `01` → `02` → `03` through `08`
4. All queries are self-contained and portable to any PostgreSQL environment

---

## 📊 Dataset

The dataset is **fully synthetic** and was purpose-built to mirror the schema and clinical patterns of the [MIMIC-III Clinical Database](https://physionet.org/content/mimiciii/1.4/) (Johnson et al., 2016). No real patient data is used. All names, dates, and identifiers are generated.

---

*Built as part of a healthcare analytics SQL portfolio. Designed to demonstrate real-world data analysis skills in one of the most in-demand analytics verticals.*
