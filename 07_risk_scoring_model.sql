-- ============================================================
-- Hospital Readmission Risk Analysis
-- File: 07_risk_scoring_model.sql
-- Description: Multi-factor readmission risk scoring model
-- Technique: Multi-CTE pipeline + CASE scoring + stratification
-- ============================================================

WITH patient_features AS (
    SELECT
        a.patient_id,
        a.admission_id,
        a.diagnosis,
        a.admission_type,
        a.discharge_location,
        a.insurance,
        EXTRACT(YEAR FROM AGE(a.admit_time, p.dob))     AS age_at_admission,
        EXTRACT(EPOCH FROM (
            a.discharge_time - a.admit_time
        ))/86400                                         AS length_of_stay_days,

        -- Number of previous admissions (running count)
        COUNT(*) OVER (
            PARTITION BY a.patient_id
            ORDER BY a.admit_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        )                                                AS prior_admissions,

        -- Count of abnormal lab results for this admission
        SUM(CASE WHEN l.flag IN ('HIGH','LOW')
            THEN 1 ELSE 0 END)                           AS abnormal_labs

    FROM admissions a
    JOIN patients p ON a.patient_id = p.patient_id
    LEFT JOIN lab_results l ON a.admission_id = l.admission_id
    GROUP BY
        a.patient_id, a.admission_id, a.diagnosis,
        a.admission_type, a.discharge_location,
        a.insurance, p.dob, a.admit_time, a.discharge_time
),
risk_scores AS (
    SELECT
        *,
        -- Risk score built from weighted clinical factors
        CASE WHEN age_at_admission >= 65        THEN 2 ELSE 0 END +
        CASE WHEN length_of_stay_days >= 7      THEN 2 ELSE 0 END +
        CASE WHEN admission_type = 'EMERGENCY'  THEN 2 ELSE 0 END +
        CASE WHEN prior_admissions >= 2         THEN 3 ELSE 0 END +
        CASE WHEN abnormal_labs >= 2            THEN 2 ELSE 0 END +
        CASE WHEN discharge_location
            IN ('SNF','HOME HEALTH CARE')       THEN 1 ELSE 0 END
                                                         AS risk_score
    FROM patient_features
)
SELECT
    patient_id,
    admission_id,
    diagnosis,
    age_at_admission,
    ROUND(length_of_stay_days::NUMERIC, 1)               AS los_days,
    admission_type,
    prior_admissions,
    abnormal_labs,
    discharge_location,
    risk_score,
    CASE
        WHEN risk_score >= 8 THEN 'HIGH'
        WHEN risk_score >= 4 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                  AS risk_category
FROM risk_scores
ORDER BY risk_score DESC;

-- Scoring weights:
--   Age >= 65              +2 pts
--   Length of stay >= 7d   +2 pts
--   Emergency admission    +2 pts
--   2+ prior admissions    +3 pts  (highest weight - strongest predictor)
--   2+ abnormal labs       +2 pts
--   SNF/Home Health Care   +1 pt
--
-- Risk bands:
--   HIGH   >= 8 points
--   MEDIUM  4-7 points
--   LOW    < 4 points
