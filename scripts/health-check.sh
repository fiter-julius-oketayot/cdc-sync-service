#!/bin/bash

# Oracle GoldenGate Health Check Script
# This script performs a comprehensive health check of the GoldenGate setup

echo "============================================"
echo "Oracle GoldenGate Health Check"
echo "============================================"
echo ""

PASS=0
FAIL=0
WARN=0

check_status() {
    if [ $1 -eq 0 ]; then
        echo "  ✓ PASS: $2"
        ((PASS++))
    else
        echo "  ✗ FAIL: $2"
        ((FAIL++))
    fi
}

check_warning() {
    if [ $1 -eq 0 ]; then
        echo "  ✓ OK: $2"
        ((PASS++))
    else
        echo "  ⚠ WARNING: $2"
        ((WARN++))
    fi
}

echo "Step 1: Checking Docker Containers..."
echo "--------------------------------------"

docker ps --format "table {{.Names}}\t{{.Status}}" | grep ogg

docker ps | grep -q ogg-oracle
check_status $? "Oracle container is running"

docker ps | grep -q ogg-postgres
check_status $? "PostgreSQL container is running"

docker ps | grep -q ogg-oracle-extract
check_status $? "GoldenGate Oracle Extract container is running"

docker ps | grep -q ogg-postgres-replicat
check_status $? "GoldenGate PostgreSQL Replicat container is running"

echo ""
echo "Step 2: Checking Oracle Database..."
echo "------------------------------------"

# Check if Oracle is accessible
docker exec ogg-oracle sqlplus -S / as sysdba << EOF > /tmp/ogg_health_oracle.txt 2>&1
SELECT 'ORACLE_ACCESSIBLE' FROM DUAL;
EXIT;
EOF

grep -q "ORACLE_ACCESSIBLE" /tmp/ogg_health_oracle.txt
check_status $? "Oracle database is accessible"

# Check ARCHIVELOG mode
ARCHIVELOG_MODE=$(docker exec ogg-oracle sqlplus -S / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT LOG_MODE FROM V\$DATABASE;
EXIT;
EOF
)

if [[ "$ARCHIVELOG_MODE" == *"ARCHIVELOG"* ]]; then
    echo "  ✓ PASS: ARCHIVELOG mode is enabled"
    ((PASS++))
else
    echo "  ✗ FAIL: ARCHIVELOG mode is NOT enabled (required for GoldenGate)"
    ((FAIL++))
fi

# Check supplemental logging
SUPP_LOG=$(docker exec ogg-oracle sqlplus -S / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT SUPPLEMENTAL_LOG_DATA_MIN FROM V\$DATABASE;
EXIT;
EOF
)

if [[ "$SUPP_LOG" == *"YES"* ]]; then
    echo "  ✓ PASS: Supplemental logging is enabled"
    ((PASS++))
else
    echo "  ✗ FAIL: Supplemental logging is NOT enabled"
    ((FAIL++))
fi

# Check if CUSTOMERS table exists
TABLE_COUNT=$(docker exec ogg-oracle sqlplus -S ogguser/oggpassword@//localhost:1521/XE << EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME='CUSTOMERS';
EXIT;
EOF
)

if [[ "$TABLE_COUNT" -ge 1 ]]; then
    echo "  ✓ PASS: OGGUSER.CUSTOMERS table exists"
    ((PASS++))
else
    echo "  ✗ FAIL: OGGUSER.CUSTOMERS table does not exist"
    ((FAIL++))
fi

echo ""
echo "Step 3: Checking PostgreSQL Database..."
echo "---------------------------------------"

# Check if PostgreSQL is accessible
docker exec ogg-postgres psql -U postgres -d postgres -c "SELECT 1;" > /tmp/ogg_health_pg.txt 2>&1
check_status $? "PostgreSQL database is accessible"

# Check if customers table exists
docker exec ogg-postgres psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='customers' AND table_schema='public';" > /tmp/ogg_pg_table.txt 2>&1
PG_TABLE_COUNT=$(cat /tmp/ogg_pg_table.txt | tr -d ' ')

if [[ "$PG_TABLE_COUNT" -ge 1 ]]; then
    echo "  ✓ PASS: public.customers table exists"
    ((PASS++))
else
    echo "  ✗ FAIL: public.customers table does not exist"
    ((FAIL++))
fi

# Check checkpoint table
docker exec ogg-postgres psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='gg_checkpoint';" > /tmp/ogg_pg_ckpt.txt 2>&1
PG_CKPT_COUNT=$(cat /tmp/ogg_pg_ckpt.txt | tr -d ' ')

if [[ "$PG_CKPT_COUNT" -ge 1 ]]; then
    echo "  ✓ PASS: GoldenGate checkpoint table exists"
    ((PASS++))
else
    echo "  ⚠ WARNING: GoldenGate checkpoint table missing"
    ((WARN++))
fi

echo ""
echo "Step 4: Checking GoldenGate Processes..."
echo "----------------------------------------"

# Check Oracle GoldenGate Manager
docker exec ogg-oracle-extract bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
INFO MGR
EXIT
EOF" > /tmp/ogg_mgr_oracle.txt 2>&1

if grep -q "RUNNING" /tmp/ogg_mgr_oracle.txt; then
    echo "  ✓ PASS: Oracle Manager is RUNNING"
    ((PASS++))
else
    echo "  ⚠ WARNING: Oracle Manager is not running"
    ((WARN++))
fi

# Check Extract
docker exec ogg-oracle-extract bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
INFO EXTRACT ext_oracle
EXIT
EOF" > /tmp/ogg_extract.txt 2>&1

if grep -q "RUNNING" /tmp/ogg_extract.txt; then
    echo "  ✓ PASS: Extract is RUNNING"
    ((PASS++))
else
    echo "  ✗ FAIL: Extract is NOT running"
    ((FAIL++))
fi

# Check Pump
docker exec ogg-oracle-extract bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
INFO EXTRACT pump_oracle
EXIT
EOF" > /tmp/ogg_pump.txt 2>&1

if grep -q "RUNNING" /tmp/ogg_pump.txt; then
    echo "  ✓ PASS: Pump is RUNNING"
    ((PASS++))
else
    echo "  ✗ FAIL: Pump is NOT running"
    ((FAIL++))
fi

# Check PostgreSQL GoldenGate Manager
docker exec ogg-postgres-replicat bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
INFO MGR
EXIT
EOF" > /tmp/ogg_mgr_pg.txt 2>&1

if grep -q "RUNNING" /tmp/ogg_mgr_pg.txt; then
    echo "  ✓ PASS: PostgreSQL Manager is RUNNING"
    ((PASS++))
else
    echo "  ⚠ WARNING: PostgreSQL Manager is not running"
    ((WARN++))
fi

# Check Replicat
docker exec ogg-postgres-replicat bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
INFO REPLICAT rep_postgres
EXIT
EOF" > /tmp/ogg_replicat.txt 2>&1

if grep -q "RUNNING" /tmp/ogg_replicat.txt; then
    echo "  ✓ PASS: Replicat is RUNNING"
    ((PASS++))
else
    echo "  ✗ FAIL: Replicat is NOT running"
    ((FAIL++))
fi

echo ""
echo "Step 5: Checking Replication Lag..."
echo "-----------------------------------"

# Extract lag
docker exec ogg-oracle-extract bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
LAG EXTRACT ext_oracle
EXIT
EOF" > /tmp/ogg_lag_extract.txt 2>&1

if grep -q "00:00:" /tmp/ogg_lag_extract.txt; then
    echo "  ✓ PASS: Extract lag is under 1 minute"
    ((PASS++))
else
    echo "  ⚠ WARNING: Extract lag may be high"
    ((WARN++))
fi

# Replicat lag
docker exec ogg-postgres-replicat bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
LAG REPLICAT rep_postgres
EXIT
EOF" > /tmp/ogg_lag_replicat.txt 2>&1

if grep -q "00:00:" /tmp/ogg_lag_replicat.txt; then
    echo "  ✓ PASS: Replicat lag is under 1 minute"
    ((PASS++))
else
    echo "  ⚠ WARNING: Replicat lag may be high"
    ((WARN++))
fi

echo ""
echo "Step 6: Checking Data Consistency..."
echo "------------------------------------"

# Row count in Oracle
ORACLE_ROWS=$(docker exec ogg-oracle sqlplus -S ogguser/oggpassword@//localhost:1521/XE << EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM CUSTOMERS;
EXIT;
EOF
)

# Row count in PostgreSQL
PG_ROWS=$(docker exec ogg-postgres psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM public.customers;")

echo "  Oracle CUSTOMERS: $ORACLE_ROWS rows"
echo "  PostgreSQL customers: $PG_ROWS rows"

if [ "$ORACLE_ROWS" == "$PG_ROWS" ]; then
    echo "  ✓ PASS: Row counts match"
    ((PASS++))
else
    echo "  ⚠ WARNING: Row counts differ (may be replication lag)"
    ((WARN++))
fi

echo ""
echo "============================================"
echo "Health Check Summary"
echo "============================================"
echo ""
echo "  ✓ Passed:  $PASS"
echo "  ⚠ Warnings: $WARN"
echo "  ✗ Failed:  $FAIL"
echo ""

if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
    echo "Result: ✓ ALL SYSTEMS OPERATIONAL"
    exit 0
elif [ $FAIL -eq 0 ]; then
    echo "Result: ⚠ OPERATIONAL WITH WARNINGS"
    exit 0
else
    echo "Result: ✗ CRITICAL ISSUES DETECTED"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check logs: docker logs ogg-oracle-extract"
    echo "  2. Check error file: docker exec ogg-oracle-extract cat /opt/oracle/ogg/ggserr.log"
    echo "  3. Review setup: ./01-setup-databases.sh"
    exit 1
fi

