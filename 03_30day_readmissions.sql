-- ============================================================
-- Hospital Readmission Risk Analysis
-- File: 03_30day_readmissions.sql
-- Description: Identify patients readmitted within 30 days
-- Technique: Self JOIN on admissions table
-- ============================================================

SELECT
    a1.patient_id,
    a1.admission_id        AS first_admission_id,
    a1.discharge_time      AS first_discharge,
    a2.admission_id        AS readmission_id,
    a2.admit_time          AS readmission_date,
    a2.diagnosis           AS readmission_diagnosis,
    DATE_PART('day', a2.admit_time - a1.discharge_time) AS days_until_readmission
FROM admissions a1
JOIN admissions a2
    ON a1.patient_id = a2.patient_id
    AND a2.admit_time > a1.discharge_time
    AND a2.admit_time <= a1.discharge_time + INTERVAL '30 days'
ORDER BY days_until_readmission ASC;

-- Result: 164 readmission events identified across the dataset
