-- =====================================================
-- Unified Database Setup SQL for Debezium CDC
-- =====================================================
-- This file contains SQL scripts for both Oracle and PostgreSQL.
--
-- For Oracle (run as SYSDBA):
--   docker cp scripts/setup.sql oracle-db:/tmp/
--   docker exec oracle-db sqlplus / as sysdba @/tmp/setup.sql
--
-- For PostgreSQL (run the PostgreSQL section manually):
--   docker exec postgres psql -U postgres -f /tmp/setup.sql
--
-- NOTE: The setup.sh script handles running these automatically.
-- =====================================================

-- =====================================================
-- ORACLE SECTION (Run as SYSDBA)
-- =====================================================
-- This section should be run in Oracle SQL*Plus as SYSDBA.
-- Skip this section if running in PostgreSQL.

/*
SET SERVEROUTPUT ON;

-- Step 1: Create CDC User (DBZUSER)
BEGIN
  EXECUTE IMMEDIATE 'DROP USER DBZUSER CASCADE';
  DBMS_OUTPUT.PUT_LINE('Dropped existing DBZUSER');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN RAISE; END IF;
END;
/

CREATE USER DBZUSER IDENTIFIED BY dbzpassword
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO DBZUSER;
GRANT CREATE SESSION TO DBZUSER;
GRANT CREATE TABLE TO DBZUSER;
GRANT CREATE SEQUENCE TO DBZUSER;

-- Step 2: Grant LogMiner & V$ View Permissions
GRANT SELECT ON V_$LOGMNR_CONTENTS TO DBZUSER;
GRANT SELECT ON V_$LOGMNR_LOGS TO DBZUSER;
GRANT SELECT ON V_$LOG TO DBZUSER;
GRANT SELECT ON V_$LOG_HISTORY TO DBZUSER;
GRANT SELECT ON V_$LOGFILE TO DBZUSER;
GRANT SELECT ON V_$ARCHIVED_LOG TO DBZUSER;
GRANT SELECT ON V_$ARCHIVE_DEST_STATUS TO DBZUSER;
GRANT SELECT ON V_$ARCHIVE_DEST TO DBZUSER;
GRANT SELECT ON V_$THREAD TO DBZUSER;
GRANT SELECT ON V_$DATABASE TO DBZUSER;
GRANT SELECT ON V_$PARAMETER TO DBZUSER;
GRANT SELECT ON V_$NLS_PARAMETERS TO DBZUSER;
GRANT SELECT ON V_$TIMEZONE_NAMES TO DBZUSER;
GRANT SELECT ON V_$TRANSACTION TO DBZUSER;
GRANT SELECT ON V_$INSTANCE TO DBZUSER;
GRANT SELECT ON V_$VERSION TO DBZUSER;
GRANT SELECT ON V_$STATNAME TO DBZUSER;
GRANT SELECT ON V_$MYSTAT TO DBZUSER;
GRANT SELECT ON V_$SYSSTAT TO DBZUSER;
GRANT SELECT ON V_$SESSION TO DBZUSER;
GRANT SELECT ON DBA_TABLESPACES TO DBZUSER;
GRANT SELECT ON DBA_OBJECTS TO DBZUSER;
GRANT SELECT ON DBA_USERS TO DBZUSER;
GRANT EXECUTE_CATALOG_ROLE TO DBZUSER;
GRANT SELECT ANY TRANSACTION TO DBZUSER;
GRANT FLASHBACK ANY TABLE TO DBZUSER;
GRANT SELECT ANY TABLE TO DBZUSER;

BEGIN
  EXECUTE IMMEDIATE 'GRANT LOGMINING TO DBZUSER';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -990 THEN NULL; ELSE RAISE; END IF;
END;
/

-- Step 3: Enable Database Supplemental Logging
BEGIN
  EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -32588 THEN NULL; ELSE RAISE; END IF;
END;
/

-- Step 4: Create CUSTOMERS Table
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE DBZUSER.CUSTOMERS';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE DBZUSER.CUSTOMERS (
  ID NUMBER(19,0) NOT NULL,
  FIRST_NAME VARCHAR2(255),
  LAST_NAME VARCHAR2(255),
  EMAIL VARCHAR2(255),
  CONSTRAINT CUSTOMERS_PK PRIMARY KEY (ID)
);

ALTER TABLE DBZUSER.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Step 5: Insert Sample Data
INSERT INTO DBZUSER.CUSTOMERS VALUES (1, 'John', 'Doe', 'john.doe@example.com');
INSERT INTO DBZUSER.CUSTOMERS VALUES (2, 'Jane', 'Smith', 'jane.smith@example.com');
INSERT INTO DBZUSER.CUSTOMERS VALUES (3, 'Bob', 'Johnson', 'bob.johnson@example.com');
COMMIT;

-- Verification
SELECT 'Database Log Mode: ' || LOG_MODE AS status FROM V$DATABASE;
SELECT 'Supplemental Logging: ' || SUPPLEMENTAL_LOG_DATA_MIN AS status FROM V$DATABASE;
SELECT 'Table Row Count: ' || COUNT(*) AS status FROM DBZUSER.CUSTOMERS;

EXIT;
*/

-- =====================================================
-- POSTGRESQL SECTION
-- =====================================================
-- This section is for PostgreSQL. Run with:
--   docker exec postgres psql -U postgres -f /tmp/setup.sql

-- Verify WAL level
\echo '====================================================='
\echo 'Verifying WAL Level Configuration'
\echo '====================================================='
SHOW wal_level;

-- Create CUSTOMERS table
\echo ''
\echo '====================================================='
\echo 'Creating CUSTOMERS Table'
\echo '====================================================='

DROP TABLE IF EXISTS public.customers;

CREATE TABLE public.customers (
    id BIGINT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255)
);

-- Set replica identity to FULL for CDC
\echo ''
\echo '====================================================='
\echo 'Setting Replica Identity to FULL'
\echo '====================================================='

ALTER TABLE public.customers REPLICA IDENTITY FULL;

-- Insert sample data
\echo ''
\echo '====================================================='
\echo 'Inserting Sample Data'
\echo '====================================================='

INSERT INTO public.customers (id, first_name, last_name, email) VALUES
    (1, 'Alice', 'Williams', 'alice.williams@example.com'),
    (2, 'Charlie', 'Brown', 'charlie.brown@example.com'),
    (3, 'Diana', 'Davis', 'diana.davis@example.com');

-- Verification
\echo ''
\echo '====================================================='
\echo 'Verification'
\echo '====================================================='

SELECT * FROM public.customers;

SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE tablename = 'customers';

SELECT relname,
       CASE relreplident
           WHEN 'd' THEN 'DEFAULT'
           WHEN 'n' THEN 'NOTHING'
           WHEN 'f' THEN 'FULL'
           WHEN 'i' THEN 'INDEX'
       END AS replica_identity
FROM pg_class
WHERE relname = 'customers';

\echo ''
\echo '====================================================='
\echo 'PostgreSQL CDC Setup Complete!'
\echo '====================================================='
\echo 'Table: public.customers created'
\echo 'Replica Identity: FULL'
\echo 'Sample data: 3 rows inserted'
\echo ''
\echo 'Next steps:'
\echo '  1. Register connectors: ./connectors.sh register'
\echo '====================================================='
