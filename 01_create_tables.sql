-- ============================================================
-- Hospital Readmission Risk Analysis
-- File: 01_create_tables.sql
-- Description: Schema definition for all 5 clinical tables
-- ============================================================

-- PATIENTS table
CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    gender CHAR(1),
    dob DATE,
    ethnicity VARCHAR(50)
);

-- ADMISSIONS table
CREATE TABLE admissions (
    admission_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    admit_time TIMESTAMP,
    discharge_time TIMESTAMP,
    admission_type VARCHAR(50),
    discharge_location VARCHAR(100),
    insurance VARCHAR(50),
    diagnosis TEXT
);

-- DIAGNOSES table
CREATE TABLE diagnoses (
    diagnosis_id SERIAL PRIMARY KEY,
    admission_id INT REFERENCES admissions(admission_id),
    icd9_code VARCHAR(10),
    description TEXT
);

-- PROCEDURES table
CREATE TABLE procedures (
    procedure_id SERIAL PRIMARY KEY,
    admission_id INT REFERENCES admissions(admission_id),
    icd9_code VARCHAR(10),
    description TEXT
);

-- LAB RESULTS table
CREATE TABLE lab_results (
    lab_id SERIAL PRIMARY KEY,
    admission_id INT REFERENCES admissions(admission_id),
    test_name VARCHAR(100),
    value NUMERIC,
    unit VARCHAR(20),
    flag VARCHAR(10)
);
