-- ============================================================
-- Hospital Readmission Risk Analysis
-- File: 05_patient_cte_summary.sql
-- Description: Patient admission history with readmission flag
-- Technique: Chained CTEs (WITH clauses)
-- ============================================================

WITH admission_summary AS (
    SELECT
        patient_id,
        COUNT(*)                                    AS total_admissions,
        MIN(admit_time)                             AS first_admission,
        MAX(admit_time)                             AS latest_admission,
        ROUND(AVG(
            EXTRACT(EPOCH FROM (discharge_time - admit_time))/86400
        )::NUMERIC, 1)                              AS avg_length_of_stay_days,
        SUM(CASE WHEN admission_type = 'EMERGENCY'
            THEN 1 ELSE 0 END)                      AS emergency_count
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
SELECT
    s.*,
    CASE WHEN r.patient_id IS NOT NULL
        THEN 'YES' ELSE 'NO' END                    AS readmitted_within_30_days
FROM admission_summary s
LEFT JOIN readmission_flags r ON s.patient_id = r.patient_id
ORDER BY total_admissions DESC;

-- CTE 1 (admission_summary): Aggregates each patient's full visit history
-- CTE 2 (readmission_flags): Identifies patients with a 30-day readmission
-- Final SELECT: Joins both CTEs for a complete patient risk profile
