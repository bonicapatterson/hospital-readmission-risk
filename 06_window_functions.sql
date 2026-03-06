-- ============================================================
-- Hospital Readmission Risk Analysis
-- File: 06_window_functions.sql
-- Description: Admission sequencing and gap analysis per patient
-- Technique: ROW_NUMBER, LAG, LEAD, PARTITION BY
-- ============================================================

SELECT
    patient_id,
    admission_id,
    admit_time,
    discharge_time,
    diagnosis,

    -- Rank each admission chronologically per patient
    ROW_NUMBER() OVER (
        PARTITION BY patient_id ORDER BY admit_time
    )                                               AS admission_number,

    -- Previous admission diagnosis (NULL for first visit)
    LAG(diagnosis) OVER (
        PARTITION BY patient_id ORDER BY admit_time
    )                                               AS previous_diagnosis,

    -- Next admission diagnosis (NULL for most recent visit)
    LEAD(diagnosis) OVER (
        PARTITION BY patient_id ORDER BY admit_time
    )                                               AS next_diagnosis,

    -- Days since last discharge (NULL for first visit)
    ROUND(DATE_PART('day',
        admit_time - LAG(discharge_time) OVER (
            PARTITION BY patient_id ORDER BY admit_time
        )
    )::NUMERIC, 0)                                  AS days_since_last_discharge

FROM admissions
ORDER BY patient_id, admit_time;

-- ROW_NUMBER(): Numbers each patient's visits 1, 2, 3...
-- LAG():        Looks back to the previous row within the partition
-- LEAD():       Looks forward to the next row within the partition
-- PARTITION BY: Resets the window calculation for each new patient
