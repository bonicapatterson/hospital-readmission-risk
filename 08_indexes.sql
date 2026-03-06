-- ============================================================
-- Hospital Readmission Risk Analysis
-- File: 08_indexes.sql
-- Description: Performance indexes for common query patterns
-- ============================================================

-- Patient lookup in admissions (used in every JOIN)
CREATE INDEX idx_admissions_patient_id
    ON admissions(patient_id);

-- Date range scans (core of 30-day readmission window logic)
CREATE INDEX idx_admissions_admit_time
    ON admissions(admit_time);

-- Lab result lookups by admission
CREATE INDEX idx_lab_results_admission_id
    ON lab_results(admission_id);

-- Diagnosis filtering by admission
CREATE INDEX idx_diagnoses_admission_id
    ON diagnoses(admission_id);

-- Composite index optimised for the self-join pattern
-- Covers both the partition (patient_id) and order (admit_time)
CREATE INDEX idx_admissions_patient_admit
    ON admissions(patient_id, admit_time);
