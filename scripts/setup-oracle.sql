-- Oracle GoldenGate Setup Script for Oracle Source Database
-- This script creates users, tables, and configures the database for GoldenGate CDC

PROMPT ===================================================
PROMPT Setting up Oracle Database for GoldenGate CDC
PROMPT ===================================================

-- Step 1: Check ARCHIVELOG mode (read-only check)
PROMPT Step 1: Checking ARCHIVELOG mode...
DECLARE
    v_log_mode VARCHAR2(20);
BEGIN
    SELECT LOG_MODE INTO v_log_mode FROM V$DATABASE;
    DBMS_OUTPUT.PUT_LINE('Current ARCHIVELOG mode: ' || v_log_mode);

    IF v_log_mode = 'NOARCHIVELOG' THEN
        DBMS_OUTPUT.PUT_LINE('Warning: ARCHIVELOG mode is not enabled.');
        DBMS_OUTPUT.PUT_LINE('This may limit GoldenGate functionality, but setup will continue.');
        DBMS_OUTPUT.PUT_LINE('Note: ARCHIVELOG can be enabled manually if needed.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ARCHIVELOG mode is enabled - good for GoldenGate!');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Could not check ARCHIVELOG mode: ' || SQLERRM);
END;
/

-- Step 2: Enable supplemental logging at database level
PROMPT Step 2: Enabling supplemental logging...
BEGIN
    EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA';
    DBMS_OUTPUT.PUT_LINE('Supplemental logging enabled successfully');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -32588 THEN
            DBMS_OUTPUT.PUT_LINE('Supplemental logging already enabled');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Warning: Could not enable supplemental logging: ' || SQLERRM);
        END IF;
END;
/

-- Step 3: Create GoldenGate Admin User
PROMPT Step 3: Creating GoldenGate admin user (oggadmin)...
DECLARE
    user_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM DBA_USERS WHERE USERNAME = 'OGGADMIN';
    IF user_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE USER oggadmin IDENTIFIED BY Welcome1
                          DEFAULT TABLESPACE USERS
                          TEMPORARY TABLESPACE TEMP';
        DBMS_OUTPUT.PUT_LINE('User OGGADMIN created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('User OGGADMIN already exists');
    END IF;
END;
/

-- Grant privileges to GoldenGate admin user
PROMPT Granting privileges to oggadmin...
GRANT DBA TO oggadmin;
GRANT CREATE SESSION TO oggadmin;
GRANT CONNECT, RESOURCE TO oggadmin;
GRANT SELECT ANY DICTIONARY TO oggadmin;
GRANT SELECT ANY TABLE TO oggadmin;
GRANT CREATE TABLE TO oggadmin;
GRANT FLASHBACK ANY TABLE TO oggadmin;
GRANT EXECUTE ON DBMS_FLASHBACK TO oggadmin;
GRANT SELECT ON SYS.V_$DATABASE TO oggadmin;
GRANT SELECT ON SYS.V_$LOG TO oggadmin;
GRANT SELECT ON SYS.V_$LOGFILE TO oggadmin;
GRANT SELECT ON SYS.V_$ARCHIVED_LOG TO oggadmin;
GRANT SELECT ON SYS.V_$ARCHIVE_DEST TO oggadmin;
GRANT SELECT ON SYS.V_$ARCHIVE_DEST_STATUS TO oggadmin;
GRANT SELECT ON SYS.V_$TRANSACTION TO oggadmin;
GRANT SELECT ON SYS.V_$STANDBY_LOG TO oggadmin;
GRANT SELECT ON SYS.V_$LOG_HISTORY TO oggadmin;
GRANT SELECT ON SYS.V_$LOGMNR_CONTENTS TO oggadmin;
GRANT SELECT ON SYS.V_$LOGMNR_LOGS TO oggadmin;

-- Step 4: Create application user
PROMPT Step 4: Creating application user (ogguser)...
DECLARE
    user_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM DBA_USERS WHERE USERNAME = 'OGGUSER';
    IF user_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE USER ogguser IDENTIFIED BY oggpassword
                          DEFAULT TABLESPACE USERS
                          TEMPORARY TABLESPACE TEMP';
        DBMS_OUTPUT.PUT_LINE('User OGGUSER created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('User OGGUSER already exists');
    END IF;
END;
/

-- Grant privileges to application user
PROMPT Granting privileges to ogguser...
GRANT CONNECT, RESOURCE TO ogguser;
GRANT CREATE SESSION TO ogguser;
GRANT CREATE TABLE TO ogguser;
GRANT UNLIMITED TABLESPACE TO ogguser;

-- Step 5: Create CUSTOMERS table
PROMPT Step 5: Creating CUSTOMERS table...
DECLARE
    table_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM DBA_TABLES
    WHERE OWNER = 'OGGUSER' AND TABLE_NAME = 'CUSTOMERS';

    IF table_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE TABLE ogguser.CUSTOMERS (
            ID NUMBER(19) PRIMARY KEY,
            FIRST_NAME VARCHAR2(255),
            LAST_NAME VARCHAR2(255),
            EMAIL VARCHAR2(255)
        )';
        DBMS_OUTPUT.PUT_LINE('Table CUSTOMERS created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Table CUSTOMERS already exists');
    END IF;
END;
/

-- Step 6: Enable supplemental logging for the table
PROMPT Step 6: Enabling supplemental logging for CUSTOMERS table...
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ogguser.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS';
    DBMS_OUTPUT.PUT_LINE('Table supplemental logging enabled successfully');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -32588 THEN
            DBMS_OUTPUT.PUT_LINE('Table supplemental logging already enabled');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Warning: Could not enable table supplemental logging: ' || SQLERRM);
        END IF;
END;
/

-- Step 7: Grant permissions for GoldenGate to read the table
PROMPT Step 7: Granting table permissions...
GRANT SELECT ON ogguser.CUSTOMERS TO oggadmin;
GRANT SELECT ON ogguser.CUSTOMERS TO public;

-- Step 8: Insert sample data
PROMPT Step 8: Inserting sample data...
BEGIN
    -- Insert sample data with duplicate handling
    BEGIN
        INSERT INTO ogguser.CUSTOMERS VALUES (1, 'John', 'Doe', 'john.doe@example.com');
        DBMS_OUTPUT.PUT_LINE('Inserted customer 1: John Doe');
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('Customer 1 already exists (John Doe)');
    END;

    BEGIN
        INSERT INTO ogguser.CUSTOMERS VALUES (2, 'Jane', 'Smith', 'jane.smith@example.com');
        DBMS_OUTPUT.PUT_LINE('Inserted customer 2: Jane Smith');
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('Customer 2 already exists (Jane Smith)');
    END;

    BEGIN
        INSERT INTO ogguser.CUSTOMERS VALUES (3, 'Bob', 'Johnson', 'bob.johnson@example.com');
        DBMS_OUTPUT.PUT_LINE('Inserted customer 3: Bob Johnson');
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('Customer 3 already exists (Bob Johnson)');
    END;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Sample data setup complete');
END;
/

-- Step 9: Verify setup
PROMPT Step 9: Verifying setup...
PROMPT Checking table row count...
SELECT 'Table row count: ' || COUNT(*) as STATUS FROM ogguser.CUSTOMERS;

PROMPT Checking supplemental logging...
SELECT 'Supplemental logging: ' || SUPPLEMENTAL_LOG_DATA_MIN as STATUS FROM V$DATABASE;

PROMPT Checking ARCHIVELOG mode...
SELECT 'Archive log mode: ' || LOG_MODE as STATUS FROM V$DATABASE;

PROMPT ===================================================
PROMPT Oracle GoldenGate Setup Complete!
PROMPT ===================================================
PROMPT Application user: ogguser/oggpassword
PROMPT GoldenGate admin user: oggadmin/Welcome1
PROMPT Table: OGGUSER.CUSTOMERS created with sample data
PROMPT Supplemental logging: Enabled
PROMPT ===================================================

