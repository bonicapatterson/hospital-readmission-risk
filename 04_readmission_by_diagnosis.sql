-- ============================================================
-- Hospital Readmission Risk Analysis
-- File: 04_readmission_by_diagnosis.sql
-- Description: 30-day readmission rate grouped by diagnosis
-- Technique: LEFT JOIN + GROUP BY + NULLIF division guard
-- ============================================================

SELECT
    a1.diagnosis,
    COUNT(DISTINCT a1.patient_id)                        AS total_patients,
    COUNT(DISTINCT a2.admission_id)                      AS readmissions,
    ROUND(
        COUNT(DISTINCT a2.admission_id)::NUMERIC /
        NULLIF(COUNT(DISTINCT a1.patient_id), 0) * 100
    , 1)                                                 AS readmission_rate_pct
FROM admissions a1
LEFT JOIN admissions a2
    ON a1.patient_id = a2.patient_id
    AND a2.admit_time > a1.discharge_time
    AND a2.admit_time <= a1.discharge_time + INTERVAL '30 days'
GROUP BY a1.diagnosis
ORDER BY readmission_rate_pct DESC NULLS LAST;

-- Note: LEFT JOIN ensures diagnoses with 0 readmissions still appear
-- NULLIF prevents division by zero errors
