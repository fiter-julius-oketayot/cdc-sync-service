#!/bin/bash

# Oracle GoldenGate CDC Test Script
# This script tests CDC replication from Oracle to PostgreSQL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "Oracle GoldenGate CDC Test"
echo "============================================"
echo ""

# Generate random test ID
TEST_ID=$((1000 + RANDOM % 9000))

# ============================================
# Pre-flight Checks
# ============================================
echo "Step 1: Pre-flight checks..."
echo "----------------------------"

# Check Oracle
if ! docker ps | grep -q oracle-db; then
    echo "✗ ERROR: oracle-db container is not running"
    exit 1
fi
echo "✓ Oracle container running"

# Check PostgreSQL
if ! docker ps | grep -q postgres-db; then
    echo "✗ ERROR: postgres-db container is not running"
    exit 1
fi
echo "✓ PostgreSQL container running"

# ============================================
# Initial Row Counts
# ============================================
echo ""
echo "Step 2: Checking initial row counts..."
echo "--------------------------------------"

ORACLE_COUNT_BEFORE=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
PG_COUNT_BEFORE=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)

echo "  Oracle CUSTOMERS:     ${ORACLE_COUNT_BEFORE:-Error} rows"
echo "  PostgreSQL customers: ${PG_COUNT_BEFORE:-Error} rows"

# ============================================
# Test INSERT
# ============================================
echo ""
echo "Step 3: Testing INSERT operation..."
echo "-----------------------------------"
echo "  Test ID: $TEST_ID"

docker exec oracle-db bash -c "echo \"INSERT INTO ogguser.CUSTOMERS VALUES ($TEST_ID, 'Test', 'GoldenGate', 'test.gg.$TEST_ID@example.com'); COMMIT; EXIT;\" | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ INSERT executed in Oracle"
else
    echo "✗ INSERT failed in Oracle"
    exit 1
fi

# Verify in Oracle
ORACLE_VERIFY=$(docker exec oracle-db bash -c "echo 'SELECT ID, FIRST_NAME, LAST_NAME FROM ogguser.CUSTOMERS WHERE ID = $TEST_ID; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep "$TEST_ID")
echo "  Oracle data: $ORACLE_VERIFY"

# ============================================
# Wait for Replication
# ============================================
echo ""
echo "Step 4: Waiting for GoldenGate replication..."
echo "----------------------------------------------"

WAIT_TIME=10
echo "  Waiting $WAIT_TIME seconds for CDC to replicate..."
sleep $WAIT_TIME

# ============================================
# Verify Replication
# ============================================
echo ""
echo "Step 5: Verifying replication in PostgreSQL..."
echo "-----------------------------------------------"

PG_RESULT=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT id, first_name, last_name, email FROM public.customers WHERE id = $TEST_ID;" 2>/dev/null)

if [ -z "$PG_RESULT" ]; then
    echo "✗ RESULT: Record NOT found in PostgreSQL"
    echo ""
    echo "This is expected if CDC processes are not yet configured."
    echo "GoldenGate Free Edition requires Web UI configuration:"
    echo ""
    echo "  1. Open https://localhost:9100 (Oracle GoldenGate)"
    echo "  2. Open https://localhost:9200 (PostgreSQL GoldenGate)"
    echo "  3. Login with: oggadmin / Welcome1!"
    echo "  4. Configure Extract and Replicat processes"
    echo ""
    echo "For monitoring: ./monitor.sh"
    REPLICATION_SUCCESS=false
else
    echo "✓ SUCCESS: Record replicated to PostgreSQL!"
    echo "  Data: $PG_RESULT"
    REPLICATION_SUCCESS=true
fi

# ============================================
# Final Row Counts
# ============================================
echo ""
echo "Step 6: Final row counts..."
echo "---------------------------"

ORACLE_COUNT_AFTER=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
PG_COUNT_AFTER=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)

echo "  Oracle CUSTOMERS:     ${ORACLE_COUNT_AFTER:-Error} rows (+$((${ORACLE_COUNT_AFTER:-0} - ${ORACLE_COUNT_BEFORE:-0})))"
echo "  PostgreSQL customers: ${PG_COUNT_AFTER:-Error} rows (+$((${PG_COUNT_AFTER:-0} - ${PG_COUNT_BEFORE:-0})))"

# ============================================
# Test UPDATE (if INSERT was replicated)
# ============================================
if [ "$REPLICATION_SUCCESS" = true ]; then
    echo ""
    echo "Step 7: Testing UPDATE operation..."
    echo "------------------------------------"

    docker exec oracle-db bash -c "echo \"UPDATE ogguser.CUSTOMERS SET FIRST_NAME='Updated', LAST_NAME='Record' WHERE ID=$TEST_ID; COMMIT; EXIT;\" | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1
    echo "✓ UPDATE executed in Oracle"

    sleep 5

    PG_UPDATED=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT first_name, last_name FROM public.customers WHERE id = $TEST_ID;" 2>/dev/null)
    echo "  PostgreSQL after UPDATE: $PG_UPDATED"

    if echo "$PG_UPDATED" | grep -q "Updated"; then
        echo "✓ UPDATE replicated successfully!"
    else
        echo "⚠ UPDATE may not have replicated yet"
    fi
fi

# ============================================
# Cleanup Option
# ============================================
echo ""
echo "============================================"
echo "Test Complete!"
echo "============================================"
echo ""
echo "To cleanup test data, run:"
echo "  docker exec oracle-db bash -c \"echo 'DELETE FROM ogguser.CUSTOMERS WHERE ID=$TEST_ID; COMMIT; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE\""
echo ""
echo "Additional test commands:"
echo ""
echo "  # Test another INSERT"
echo "  docker exec oracle-db bash -c \"echo 'INSERT INTO ogguser.CUSTOMERS VALUES (\$RANDOM, '\\''John'\\'' , '\\''Doe'\\'' , '\\''john@example.com'\\'' ); COMMIT; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE\""
echo ""
echo "  # Check PostgreSQL"
echo "  docker exec postgres-db psql -U postgres -d postgres -c 'SELECT * FROM public.customers ORDER BY id DESC LIMIT 5;'"
echo ""
