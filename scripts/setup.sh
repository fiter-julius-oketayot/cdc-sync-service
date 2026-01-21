#!/bin/bash
# =====================================================
# Unified Database Setup Script for Debezium CDC
# =====================================================
# This script handles setup for both Oracle and PostgreSQL:
# - Oracle: Enables ARCHIVELOG mode, creates DBZUSER, tables
# - PostgreSQL: Verifies WAL level, creates tables
#
# Usage:
#   ./setup.sh          - Setup both databases
#   ./setup.sh oracle   - Setup Oracle only
#   ./setup.sh postgres - Setup PostgreSQL only
#   ./setup.sh help     - Show help
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# =====================================================
# Oracle Setup Functions
# =====================================================

wait_for_oracle() {
    echo "Waiting for Oracle to be ready..."
    for i in {1..60}; do
        if docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
SELECT 1 FROM DUAL;
EXIT;
EOF' > /dev/null 2>&1; then
            print_success "Oracle is ready!"
            return 0
        fi
        echo -n "."
        sleep 5
    done
    echo ""
    print_error "Oracle failed to start within 5 minutes"
    return 1
}

setup_oracle_archivelog() {
    print_header "Checking Oracle ARCHIVELOG Status"

    # First check if database is open using heredoc (more reliable)
    echo "Checking database status..."
    DB_STATUS=$(docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT STATUS FROM V\$INSTANCE;
EXIT;
EOF' 2>/dev/null | grep -v "^$" | tr -d '[:space:]')

    echo "Database status: $DB_STATUS"

    if [ "$DB_STATUS" != "OPEN" ]; then
        echo "Database is not OPEN (status: $DB_STATUS). Attempting to open..."
        docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
STARTUP;
EXIT;
EOF' 2>/dev/null || true
        sleep 10
    fi

    # Check LOG_MODE using heredoc
    LOG_MODE=$(docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT LOG_MODE FROM V\$DATABASE;
EXIT;
EOF' 2>/dev/null | grep -v "^$" | tr -d '[:space:]')

    echo "Current LOG_MODE: '$LOG_MODE'"

    if [ "$LOG_MODE" = "ARCHIVELOG" ]; then
        print_success "Database is already in ARCHIVELOG mode"
        return 0
    fi

    echo "Database is in NOARCHIVELOG mode - Enabling ARCHIVELOG..."

    # Set recovery parameters
    echo "Setting recovery file destination..."
    docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
ALTER SYSTEM SET db_recovery_file_dest_size = 10G SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest = '\''/opt/oracle/oradata'\'' SCOPE=BOTH;
EXIT;
EOF'

    # Shutdown, mount, enable archivelog, open - all in one SQL*Plus session
    echo "Restarting database in ARCHIVELOG mode (this may take a minute)..."
    docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
EXIT;
EOF'

    # Wait for database to be fully open
    echo "Waiting for database to be fully open..."
    sleep 15

    for i in {1..30}; do
        DB_STATUS=$(docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT STATUS FROM V\$INSTANCE;
EXIT;
EOF' 2>/dev/null | grep -v "^$" | tr -d '[:space:]')
        if [ "$DB_STATUS" = "OPEN" ]; then
            echo "Database is OPEN"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""

    # Verify LOG_MODE
    NEW_LOG_MODE=$(docker exec oracle-db bash -c 'sqlplus -S / as sysdba << EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT LOG_MODE FROM V\$DATABASE;
EXIT;
EOF' 2>/dev/null | grep -v "^$" | tr -d '[:space:]')

    echo "Detected LOG_MODE: '$NEW_LOG_MODE'"

    if [ "$NEW_LOG_MODE" = "ARCHIVELOG" ]; then
        print_success "ARCHIVELOG mode enabled successfully!"
    else
        print_warning "Could not verify ARCHIVELOG mode (got: '$NEW_LOG_MODE'). Continuing with schema setup..."
        # Don't fail here - the schema setup might still work
    fi
}

setup_oracle_schema() {
    print_header "Running Oracle Schema Setup"

    # Extract Oracle SQL section and run it
    docker exec -i oracle-db sqlplus -S / as sysdba <<'EOSQL'
SET SERVEROUTPUT ON;

PROMPT Creating CDC User (DBZUSER)...

-- Drop user if exists
BEGIN
  EXECUTE IMMEDIATE 'DROP USER DBZUSER CASCADE';
  DBMS_OUTPUT.PUT_LINE('Dropped existing DBZUSER');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN
      RAISE;
    END IF;
END;
/

-- Create DBZUSER
CREATE USER DBZUSER IDENTIFIED BY dbzpassword
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- Grant basic privileges
GRANT CONNECT, RESOURCE TO DBZUSER;
GRANT CREATE SESSION TO DBZUSER;
GRANT CREATE TABLE TO DBZUSER;
GRANT CREATE SEQUENCE TO DBZUSER;

PROMPT Granting LogMiner & V$ View Permissions...

-- LogMiner views
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

-- LogMining privilege (Oracle 12c+)
BEGIN
  EXECUTE IMMEDIATE 'GRANT LOGMINING TO DBZUSER';
  DBMS_OUTPUT.PUT_LINE('LOGMINING privilege granted');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -990 THEN
      DBMS_OUTPUT.PUT_LINE('LOGMINING privilege not available (Oracle < 12c)');
    ELSE
      RAISE;
    END IF;
END;
/

PROMPT Enabling Database Supplemental Logging...

BEGIN
  EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA';
  DBMS_OUTPUT.PUT_LINE('Database supplemental logging enabled');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -32588 THEN
      DBMS_OUTPUT.PUT_LINE('Supplemental logging already enabled');
    ELSE
      RAISE;
    END IF;
END;
/

PROMPT Creating CUSTOMERS Table...

-- Drop table if exists
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE DBZUSER.CUSTOMERS';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
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

PROMPT Inserting Sample Data...

INSERT INTO DBZUSER.CUSTOMERS VALUES (1, 'John', 'Doe', 'john.doe@example.com');
INSERT INTO DBZUSER.CUSTOMERS VALUES (2, 'Jane', 'Smith', 'jane.smith@example.com');
INSERT INTO DBZUSER.CUSTOMERS VALUES (3, 'Bob', 'Johnson', 'bob.johnson@example.com');
COMMIT;

PROMPT
PROMPT Verification:
SELECT 'Database Log Mode: ' || LOG_MODE AS status FROM V$DATABASE;
SELECT 'Supplemental Logging: ' || SUPPLEMENTAL_LOG_DATA_MIN AS status FROM V$DATABASE;
SELECT 'Table Row Count: ' || COUNT(*) AS status FROM DBZUSER.CUSTOMERS;

EXIT;
EOSQL

    print_success "Oracle schema setup complete"
}

setup_oracle() {
    print_header "Oracle CDC Setup"

    # Check if Oracle container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^oracle-db$"; then
        print_error "Oracle container 'oracle-db' is not running"
        echo "Please start it with: docker-compose up -d oracle"
        return 1
    fi

    wait_for_oracle || return 1
    setup_oracle_archivelog || return 1
    setup_oracle_schema || return 1

    print_header "Oracle CDC Setup Complete!"
    print_success "User: DBZUSER created with LogMiner permissions"
    print_success "Table: DBZUSER.CUSTOMERS created with supplemental logging"
    print_success "Sample data: 3 rows inserted"
}

# =====================================================
# PostgreSQL Setup Functions
# =====================================================

wait_for_postgres() {
    echo "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker exec postgres psql -U postgres -c "SELECT 1" > /dev/null 2>&1; then
            print_success "PostgreSQL is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    print_error "PostgreSQL failed to start within 60 seconds"
    return 1
}

setup_postgres() {
    print_header "PostgreSQL CDC Setup"

    # Check if PostgreSQL container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^postgres$"; then
        print_error "PostgreSQL container 'postgres' is not running"
        echo "Please start it with: docker-compose up -d postgres"
        return 1
    fi

    wait_for_postgres || return 1

    # Verify WAL level
    print_header "Verifying WAL Level"
    WAL_LEVEL=$(docker exec postgres psql -U postgres -t -c "SHOW wal_level;" 2>/dev/null | xargs)

    if [ "$WAL_LEVEL" = "logical" ]; then
        print_success "WAL level is 'logical'"
    else
        print_error "WAL level is '$WAL_LEVEL' (expected 'logical')"
        echo "Please ensure docker-compose.yml has: command: postgres -c wal_level=logical"
        return 1
    fi

    # Run PostgreSQL setup
    print_header "Running PostgreSQL Schema Setup"

    docker exec -i postgres psql -U postgres <<'EOSQL'
-- Drop table if exists
DROP TABLE IF EXISTS public.customers;

-- Create CUSTOMERS table
CREATE TABLE public.customers (
    id BIGINT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255)
);

-- Set REPLICA IDENTITY FULL for CDC
ALTER TABLE public.customers REPLICA IDENTITY FULL;

-- Insert sample data
INSERT INTO public.customers (id, first_name, last_name, email) VALUES
    (1, 'Alice', 'Williams', 'alice.williams@example.com'),
    (2, 'Charlie', 'Brown', 'charlie.brown@example.com'),
    (3, 'Diana', 'Davis', 'diana.davis@example.com');

-- Verification
\echo 'Table contents:'
SELECT * FROM public.customers;

\echo 'Replica identity:'
SELECT relname,
       CASE relreplident
           WHEN 'd' THEN 'DEFAULT'
           WHEN 'n' THEN 'NOTHING'
           WHEN 'f' THEN 'FULL'
           WHEN 'i' THEN 'INDEX'
       END AS replica_identity
FROM pg_class
WHERE relname = 'customers';
EOSQL

    print_header "PostgreSQL CDC Setup Complete!"
    print_success "Table: public.customers created"
    print_success "Replica Identity: FULL"
    print_success "Sample data: 3 rows inserted"
}

# =====================================================
# Main
# =====================================================

show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  (none)    - Setup both Oracle and PostgreSQL"
    echo "  oracle    - Setup Oracle only"
    echo "  postgres  - Setup PostgreSQL only"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Setup both databases"
    echo "  $0 oracle       # Setup Oracle only"
    echo "  $0 postgres     # Setup PostgreSQL only"
}

case "${1:-all}" in
    all|both)
        setup_oracle
        echo ""
        setup_postgres
        print_header "All Database Setup Complete!"
        echo ""
        echo "Next steps:"
        echo "  1. Register connectors: ./connectors.sh register"
        echo "  2. Run health check: ./health-check.sh"
        echo "  3. Start the application: ./gradlew bootRun"
        ;;
    oracle|ora|o)
        setup_oracle
        echo ""
        echo "Next steps:"
        echo "  1. Setup PostgreSQL: ./setup.sh postgres"
        echo "  2. Register connectors: ./connectors.sh register"
        ;;
    postgres|pg|p)
        setup_postgres
        echo ""
        echo "Next steps:"
        echo "  1. Setup Oracle: ./setup.sh oracle"
        echo "  2. Register connectors: ./connectors.sh register"
        ;;
    help|h|-h|--help)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
