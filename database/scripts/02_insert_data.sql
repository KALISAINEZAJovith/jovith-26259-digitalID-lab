-- =====================================================
-- PHASE V: DATA INSERTION SCRIPT (PART 1 OF 2)
-- Project: Digital ID Data Privacy and Access Monitoring System
-- Student: KALISA INEZA JOVITH (26259)
-- This script inserts 100-500+ realistic rows per table
-- =====================================================

SET SERVEROUTPUT ON;
SET DEFINE OFF;

-- =====================================================
-- 1. INSERT DATA_CATEGORIES (10-15 rows)
-- =====================================================
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'PERSONAL_INFO', 'Name, DOB, Address', 2, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'CONTACT_DETAILS', 'Email, Phone', 1, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'BIOMETRIC_DATA', 'Fingerprint, Facial Recognition', 5, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'FINANCIAL_INFO', 'Bank Accounts, Income', 4, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'HEALTH_RECORDS', 'Medical History, Conditions', 5, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'EMPLOYMENT_DATA', 'Job Title, Employer', 3, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'EDUCATION_RECORDS', 'Schools, Degrees', 2, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'TRAVEL_HISTORY', 'Border Crossings, Visas', 3, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'CRIMINAL_RECORD', 'Arrests, Convictions', 4, 'Y', SYSTIMESTAMP);
INSERT INTO data_categories VALUES (seq_category_id.NEXTVAL, 'SOCIAL_MEDIA', 'Public Profiles, Posts', 1, 'N', SYSTIMESTAMP);

COMMIT;

-- =====================================================
-- 2. INSERT HOLIDAYS (20-30 rows for 2025-2026)
-- =====================================================
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'New Year Day', DATE '2025-01-01', 'PUBLIC', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Liberation Day', DATE '2025-07-04', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Genocide Memorial Day', DATE '2025-04-07', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Heroes Day', DATE '2025-02-01', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Umuganura Day', DATE '2025-08-01', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Christmas Day', DATE '2025-12-25', 'RELIGIOUS', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Boxing Day', DATE '2025-12-26', 'PUBLIC', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Good Friday', DATE '2025-04-18', 'RELIGIOUS', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Easter Monday', DATE '2025-04-21', 'RELIGIOUS', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Eid al-Fitr', DATE '2025-04-03', 'RELIGIOUS', 'N', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Eid al-Adha', DATE '2025-06-10', 'RELIGIOUS', 'N', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Independence Day', DATE '2025-07-01', 'NATIONAL', 'Y', SYSTIMESTAMP);
-- Add 2026 holidays
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'New Year Day 2026', DATE '2026-01-01', 'PUBLIC', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Heroes Day 2026', DATE '2026-02-01', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Genocide Memorial Day 2026', DATE '2026-04-07', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Liberation Day 2026', DATE '2026-07-04', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Umuganura Day 2026', DATE '2026-08-01', 'NATIONAL', 'Y', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Christmas Day 2026', DATE '2026-12-25', 'RELIGIOUS', 'Y', SYSTIMESTAMP);
-- Emergency closure days
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'System Maintenance Day', DATE '2025-12-10', 'PUBLIC', 'N', SYSTIMESTAMP);
INSERT INTO holidays VALUES (seq_holiday_id.NEXTVAL, 'Year-End Closure', DATE '2025-12-31', 'PUBLIC', 'Y', SYSTIMESTAMP);

COMMIT;

-- =====================================================
-- 3. INSERT AUTHORIZED_ENTITIES (50-100 rows)
-- =====================================================

-- Government Entities
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Rwanda Revenue Authority', 'GOVERNMENT', 'GOV-RRA-2024-001', 'Jean Pierre Mugabo', 'info@rra.gov.rw', '+250788123001', 3, DATE '2024-01-15', DATE '2026-01-15', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'National Police of Rwanda', 'GOVERNMENT', 'GOV-NPR-2024-002', 'Diane Uwase', 'contact@police.gov.rw', '+250788123002', 3, DATE '2024-02-01', DATE '2026-02-01', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Ministry of Justice', 'GOVERNMENT', 'GOV-MOJ-2024-003', 'Eric Nsabimana', 'info@minijust.gov.rw', '+250788123003', 3, DATE '2024-01-20', DATE '2026-01-20', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Immigration Directorate', 'GOVERNMENT', 'GOV-IMG-2024-004', 'Grace Umutoni', 'immigration@gov.rw', '+250788123004', 3, DATE '2024-03-01', DATE '2026-03-01', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Social Security Board', 'GOVERNMENT', 'GOV-SSB-2024-005', 'Patrick Habimana', 'info@ssb.gov.rw', '+250788123005', 2, DATE '2024-02-15', DATE '2026-02-15', 'ACTIVE', SYSTIMESTAMP);

-- Banks
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Bank of Kigali', 'BANK', 'BANK-BK-2024-001', 'Sarah Mukamana', 'compliance@bk.rw', '+250788124001', 2, DATE '2024-01-10', DATE '2026-01-10', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Equity Bank Rwanda', 'BANK', 'BANK-EQT-2024-002', 'James Niyonzima', 'kyc@equitybank.rw', '+250788124002', 2, DATE '2024-01-12', DATE '2026-01-12', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'KCB Bank Rwanda', 'BANK', 'BANK-KCB-2024-003', 'Claire Uwera', 'info@kcb.rw', '+250788124003', 2, DATE '2024-02-01', DATE '2026-02-01', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Access Bank Rwanda', 'BANK', 'BANK-ACC-2024-004', 'David Mugisha', 'compliance@accessbank.rw', '+250788124004', 2, DATE '2024-01-25', DATE '2026-01-25', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Cogebanque', 'BANK', 'BANK-COG-2024-005', 'Alice Ingabire', 'kyc@cogebanque.rw', '+250788124005', 2, DATE '2024-02-10', DATE '2026-02-10', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'I&M Bank Rwanda', 'BANK', 'BANK-IM-2024-006', 'Robert Kayitare', 'compliance@imbank.rw', '+250788124006', 2, DATE '2024-03-01', DATE '2026-03-01', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'GT Bank Rwanda', 'BANK', 'BANK-GT-2024-007', 'Betty Uwamahoro', 'info@gtbank.rw', '+250788124007', 2, DATE '2024-01-15', DATE '2026-01-15', 'ACTIVE', SYSTIMESTAMP);

-- Hospitals
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'King Faisal Hospital', 'HOSPITAL', 'HOSP-KFH-2024-001', 'Dr. Emmanuel Nshuti', 'admin@kfh.rw', '+250788125001', 3, DATE '2024-01-05', DATE '2026-01-05', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'University Teaching Hospital Kigali', 'HOSPITAL', 'HOSP-CHUK-2024-002', 'Dr. Marie Mukamana', 'info@chuk.gov.rw', '+250788125002', 3, DATE '2024-01-10', DATE '2026-01-10', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Rwanda Military Hospital', 'HOSPITAL', 'HOSP-RMH-2024-003', 'Dr. Jean Claude Bizimana', 'contact@rmh.gov.rw', '+250788125003', 3, DATE '2024-02-01', DATE '2026-02-01', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Kibagabaga Hospital', 'HOSPITAL', 'HOSP-KIB-2024-004', 'Dr. Agnes Nyirahabimana', 'info@kibagabaga.rw', '+250788125004', 2, DATE '2024-01-20', DATE '2026-01-20', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Nyarugenge Hospital', 'HOSPITAL', 'HOSP-NYA-2024-005', 'Dr. Joseph Niyonkuru', 'contact@nyarugenge.rw', '+250788125005', 2, DATE '2024-02-15', DATE '2026-02-15', 'ACTIVE', SYSTIMESTAMP);

-- Insurance Companies
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'SORAS Insurance', 'INSURANCE', 'INS-SOR-2024-001', 'Christine Umutesi', 'claims@soras.rw', '+250788126001', 2, DATE '2024-01-08', DATE '2026-01-08', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'SONARWA General Insurance', 'INSURANCE', 'INS-SONA-2024-002', 'Francis Muhire', 'info@sonarwa.rw', '+250788126002', 2, DATE '2024-01-15', DATE '2026-01-15', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Radiant Insurance', 'INSURANCE', 'INS-RAD-2024-003', 'Lucy Kagabo', 'support@radiant.rw', '+250788126003', 2, DATE '2024-02-01', DATE '2026-02-01', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Prime Insurance', 'INSURANCE', 'INS-PRM-2024-004', 'Thomas Nshimiyimana', 'info@prime.rw', '+250788126004', 2, DATE '2024-01-20', DATE '2026-01-20', 'ACTIVE', SYSTIMESTAMP);

-- Telecom
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'MTN Rwanda', 'TELECOM', 'TEL-MTN-2024-001', 'Peter Ndagijimana', 'legal@mtn.rw', '+250788127001', 1, DATE '2024-01-05', DATE '2026-01-05', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Airtel Rwanda', 'TELECOM', 'TEL-AIR-2024-002', 'Sandra Uwizeye', 'compliance@airtel.rw', '+250788127002', 1, DATE '2024-01-10', DATE '2026-01-10', 'ACTIVE', SYSTIMESTAMP);

-- Add more entities (targeting 50+ total)
-- Suspended/Revoked entities for testing
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Global Credit Ltd', 'BANK', 'BANK-GCL-2023-999', 'John Doe', 'info@globalcredit.rw', '+250788129999', 1, DATE '2023-06-01', DATE '2024-06-01', 'REVOKED', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'QuickLoan Services', 'OTHER', 'OTH-QLS-2024-888', 'Jane Smith', 'support@quickloan.rw', '+250788129888', 1, DATE '2024-03-01', DATE '2024-09-01', 'SUSPENDED', SYSTIMESTAMP);

-- More government agencies
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Rwanda Development Board', 'GOVERNMENT', 'GOV-RDB-2024-006', 'Martin Gakwaya', 'info@rdb.rw', '+250788123006', 2, DATE '2024-01-10', DATE '2026-01-10', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'National Electoral Commission', 'GOVERNMENT', 'GOV-NEC-2024-007', 'Flora Mukamana', 'contact@nec.gov.rw', '+250788123007', 3, DATE '2024-02-01', DATE '2026-02-01', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'RSSB Social Security', 'GOVERNMENT', 'GOV-RSSB-2024-008', 'Joseph Nsengimana', 'info@rssb.rw', '+250788123008', 2, DATE '2024-01-15', DATE '2026-01-15', 'ACTIVE', SYSTIMESTAMP);

-- More banks
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'BPR Bank Rwanda', 'BANK', 'BANK-BPR-2024-008', 'Marie Umuhoza', 'compliance@bpr.rw', '+250788124008', 2, DATE '2024-02-05', DATE '2026-02-05', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Unguka Bank', 'BANK', 'BANK-UNG-2024-009', 'Eric Manzi', 'kyc@ungukabank.rw', '+250788124009', 2, DATE '2024-02-20', DATE '2026-02-20', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'AB Bank Rwanda', 'BANK', 'BANK-AB-2024-010', 'Christine Nyiransabimana', 'info@abbank.rw', '+250788124010', 2, DATE '2024-03-01', DATE '2026-03-01', 'ACTIVE', SYSTIMESTAMP);

-- More hospitals & clinics
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Polyclinique La Medicale', 'HOSPITAL', 'HOSP-PLM-2024-006', 'Dr. Patrick Uwimana', 'contact@lamedicale.rw', '+250788125006', 2, DATE '2024-01-25', DATE '2026-01-25', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Oshen King Faisal Hospital', 'HOSPITAL', 'HOSP-OKF-2024-007', 'Dr. Serge Mutabazi', 'admin@oshen.rw', '+250788125007', 2, DATE '2024-02-10', DATE '2026-02-10', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'Kigali Eye Clinic', 'HOSPITAL', 'HOSP-KEC-2024-008', 'Dr. Alice Mukamana', 'info@kigalieye.rw', '+250788125008', 2, DATE '2024-02-15', DATE '2026-02-15', 'ACTIVE', SYSTIMESTAMP);

-- More insurance
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'UAP Insurance Rwanda', 'INSURANCE', 'INS-UAP-2024-005', 'Patrick Mugabo', 'claims@uap.rw', '+250788126005', 2, DATE '2024-02-05', DATE '2026-02-05', 'ACTIVE', SYSTIMESTAMP);
INSERT INTO authorized_entities VALUES (seq_entity_id.NEXTVAL, 'MEDIS Medical Insurance', 'INSURANCE', 'INS-MED-2024-006', 'Grace Uwimana', 'support@medis.rw', '+250788126006', 2, DATE '2024-02-10', DATE '2026-02-10', 'ACTIVE', SYSTIMESTAMP);

COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Data Categories: ' || (SELECT COUNT(*) FROM data_categories));
    DBMS_OUTPUT.PUT_LINE('Holidays: ' || (SELECT COUNT(*) FROM holidays));
    DBMS_OUTPUT.PUT_LINE('Authorized Entities: ' || (SELECT COUNT(*) FROM authorized_entities));
    DBMS_OUTPUT.PUT_LINE('Continue with Part 2 for Citizens and remaining tables...');
END;
/