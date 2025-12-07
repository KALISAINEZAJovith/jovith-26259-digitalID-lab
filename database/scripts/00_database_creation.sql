

-- Check existing PDBs
SELECT pdb_name, status FROM dba_pdbs;

-- Create Pluggable Database
CREATE PLUGGABLE DATABASE mon_26259_jovith_digitalID_db
  ADMIN USER pdb_admin IDENTIFIED BY jovith
  FILE_NAME_CONVERT = (
    'C:\oracleApp\oradata\FREE\pdbseed\',
    'C:\oracleApp\oradata\FREE\mon_26259_jovith_digitalID_db\'
  )
  STORAGE (MAXSIZE 2G)
  DEFAULT TABLESPACE users
  DATAFILE 'C:\oracleApp\oradata\FREE\mon_26259_jovith_digitalID_db\users01.dbf'
  SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE 500M
  PATH_PREFIX = 'C:\oracleApp\oradata\FREE\mon_26259_jovith_digitalID_db\';

--: Open the PDB
ALTER PLUGGABLE DATABASE mon_26259_jovith_digitalID_db OPEN;

--: Set PDB to open automatically on startup
ALTER PLUGGABLE DATABASE mon_26259_jovith_digitalID_db SAVE STATE;

--: Switch to the PDB
ALTER SESSION SET CONTAINER = mon_26259_jovith_digitalID_db;

--: Verify connection
SHOW CON_NAME;
SELECT name, open_mode FROM v$pdbs;

-- =====================================================
-- TABLESPACE CONFIGURATION
-- =====================================================

-- Create Tablespace for DATA
CREATE TABLESPACE digitalid_data
  DATAFILE 'C:\oracleApp\oradata\FREE\mon_26259_jovith_digitalID_db\digitalid_data01.dbf'
  SIZE 200M
  AUTOEXTEND ON
  NEXT 50M
  MAXSIZE 1G
  EXTENT MANAGEMENT LOCAL
  SEGMENT SPACE MANAGEMENT AUTO;

-- Create Tablespace for INDEXES
CREATE TABLESPACE digitalid_indexes
  DATAFILE 'C:\oracleApp\oradata\FREE\mon_26259_jovith_digitalID_db\digitalid_indexes01.dbf'
  SIZE 100M
  AUTOEXTEND ON
  NEXT 20M
  MAXSIZE 500M
  EXTENT MANAGEMENT LOCAL
  SEGMENT SPACE MANAGEMENT AUTO;

-- Create Temporary Tablespace
CREATE TEMPORARY TABLESPACE digitalid_temp
  TEMPFILE 'C:\oracleApp\oradata\FREE\mon_26259_jovith_digitalID_db\digitalid_temp01.dbf'
  SIZE 100M
  AUTOEXTEND ON
  NEXT 20M
  MAXSIZE 500M
  EXTENT MANAGEMENT LOCAL;

-- Verify tablespaces
SELECT tablespace_name, status, contents FROM dba_tablespaces
WHERE tablespace_name LIKE 'DIGITALID%';

-- =====================================================
-- USER CREATION AND PRIVILEGES
-- =====================================================

-- Create Main Application User
CREATE USER jovith_admin
  IDENTIFIED BY jovith
  DEFAULT TABLESPACE digitalid_data
  TEMPORARY TABLESPACE digitalid_temp
  QUOTA UNLIMITED ON digitalid_data
  QUOTA UNLIMITED ON digitalid_indexes;

-- Grant System Privileges
GRANT CONNECT, RESOURCE, DBA TO jovith_admin;
GRANT CREATE SESSION TO jovith_admin;
GRANT CREATE TABLE TO jovith_admin;
GRANT CREATE VIEW TO jovith_admin;
GRANT CREATE SEQUENCE TO jovith_admin;
GRANT CREATE PROCEDURE TO jovith_admin;
GRANT CREATE TRIGGER TO jovith_admin;
GRANT CREATE SYNONYM TO jovith_admin;
GRANT UNLIMITED TABLESPACE TO jovith_admin;

-- Grant Object Privileges
GRANT SELECT ANY TABLE TO jovith_admin;
GRANT INSERT ANY TABLE TO jovith_admin;
GRANT UPDATE ANY TABLE TO jovith_admin;
GRANT DELETE ANY TABLE TO jovith_admin;
GRANT EXECUTE ANY PROCEDURE TO jovith_admin;

-- Create Read-Only User (for BI/reporting)
CREATE USER jovith_reader
  IDENTIFIED BY reader123
  DEFAULT TABLESPACE digitalid_data
  TEMPORARY TABLESPACE digitalid_temp
  QUOTA 0 ON digitalid_data;

-- Grant Read-Only Privileges
GRANT CONNECT TO jovith_reader;
GRANT CREATE SESSION TO jovith_reader;
GRANT SELECT ANY TABLE TO jovith_reader;

-- =====================================================
-- MEMORY CONFIGURATION
-- =====================================================

-- Check current memory parameters
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;

-- Set memory parameters (adjust based on your system)
-- For systems with 8GB+ RAM, these are recommended
ALTER SYSTEM SET sga_target = 2G SCOPE=SPFILE;
ALTER SYSTEM SET pga_aggregate_target = 1G SCOPE=SPFILE;

-- For smaller systems (4GB RAM), use these instead:
-- ALTER SYSTEM SET sga_target = 1G SCOPE=SPFILE;
-- ALTER SYSTEM SET pga_aggregate_target = 512M SCOPE=SPFILE;

-- =====================================================
-- ARCHIVE LOG CONFIGURATION
-- =====================================================

-- Check archive log mode
ARCHIVE LOG LIST;

ALTER PLUGGABLE DATABASE ALL CLOSE;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;

-- =====================================================
-- VERIFY INSTALLATION
-- =====================================================

-- Connect as application user
CONNECT jovith_admin/jovith@localhost:1521/mon_26259_jovith_digitalID_db

-- Test connection
SELECT user, sys_context('USERENV', 'CON_NAME') AS container FROM dual;

-- Check tablespaces
SELECT tablespace_name, bytes/1024/1024 AS size_mb, maxbytes/1024/1024 AS max_mb
FROM user_ts_quotas;

-- Check privileges
SELECT * FROM user_sys_privs ORDER BY privilege;

-- =====================================================
-- PROJECT STRUCTURE SETUP
-- =====================================================

-- Create sequences for primary keys
CREATE SEQUENCE seq_citizen_id START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE seq_digital_id START WITH 5000 INCREMENT BY 1;
CREATE SEQUENCE seq_entity_id START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_request_id START WITH 10000 INCREMENT BY 1;
CREATE SEQUENCE seq_consent_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_log_id START WITH 100000 INCREMENT BY 1;
CREATE SEQUENCE seq_alert_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_category_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_holiday_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_violation_id START WITH 1 INCREMENT BY 1;

-- Verify sequences
SELECT sequence_name, last_number FROM user_sequences;



