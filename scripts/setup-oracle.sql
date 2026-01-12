-- =====================================================
-- Oracle Database Setup for Debezium CDC (Simplified)
-- =====================================================
-- Run this as SYSTEM user
-- Connect: sqlplus system/oracle@//localhost:1521/XE
--
-- This simplified version uses only the SYSTEM user/schema
-- No separate CDC user or INVENTORY schema needed

-- Step 1: Enable ARCHIVELOG mode (required for Debezium CDC)
-- Check if already in archivelog mode
DECLARE
  v_log_mode VARCHAR2(20);
BEGIN
  SELECT LOG_MODE INTO v_log_mode FROM V$DATABASE;

  IF v_log_mode = 'NOARCHIVELOG' THEN
    DBMS_OUTPUT.PUT_LINE('Enabling ARCHIVELOG mode...');
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET db_recovery_file_dest_size = 10G SCOPE=BOTH';
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET db_recovery_file_dest = ''/opt/oracle/oradata/recovery_area'' SCOPE=BOTH';
    EXECUTE IMMEDIATE 'SHUTDOWN IMMEDIATE';
    EXECUTE IMMEDIATE 'STARTUP MOUNT';
    EXECUTE IMMEDIATE 'ALTER DATABASE ARCHIVELOG';
    EXECUTE IMMEDIATE 'ALTER DATABASE OPEN';
    DBMS_OUTPUT.PUT_LINE('ARCHIVELOG mode enabled successfully');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Database already in ARCHIVELOG mode');
  END IF;
END;
/

-- Step 2: Enable database-level supplemental logging
-- This ensures all transactions are logged with enough detail for CDC
BEGIN
  EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -32588 THEN
      DBMS_OUTPUT.PUT_LINE('Supplemental logging already enabled');
    ELSE
      RAISE;
    END IF;
END;
/

-- Step 3: Create CUSTOMERS table in SYSTEM schema
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE SYSTEM.CUSTOMERS';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/

CREATE TABLE SYSTEM.CUSTOMERS (
  ID NUMBER(19) PRIMARY KEY,
  FIRST_NAME VARCHAR2(255),
  LAST_NAME VARCHAR2(255),
  EMAIL VARCHAR2(255)
);

-- Step 4: Enable table-level supplemental logging for CDC
-- This captures the entire row for updates (before and after values)
ALTER TABLE SYSTEM.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Step 5: Insert sample data for testing
INSERT INTO SYSTEM.CUSTOMERS (ID, FIRST_NAME, LAST_NAME, EMAIL)
  VALUES (1, 'John', 'Doe', 'john.doe@example.com');
INSERT INTO SYSTEM.CUSTOMERS (ID, FIRST_NAME, LAST_NAME, EMAIL)
  VALUES (2, 'Jane', 'Smith', 'jane.smith@example.com');
INSERT INTO SYSTEM.CUSTOMERS (ID, FIRST_NAME, LAST_NAME, EMAIL)
  VALUES (3, 'Bob', 'Johnson', 'bob.johnson@example.com');
COMMIT;

-- Verify setup
SELECT 'Database log mode: ' || LOG_MODE AS status FROM V$DATABASE;
SELECT 'Database supplemental logging: ' || SUPPLEMENTAL_LOG_DATA_MIN AS status FROM V$DATABASE;
SELECT 'Table count: ' || COUNT(*) AS customer_count FROM SYSTEM.CUSTOMERS;

-- Display success message
PROMPT
PROMPT ===================================================
PROMPT Oracle CDC Setup Complete!
PROMPT ===================================================
PROMPT Table: SYSTEM.CUSTOMERS created
PROMPT Sample data: 3 rows inserted
PROMPT Supplemental logging: Enabled
PROMPT Archive log mode: Check status above
PROMPT ===================================================

