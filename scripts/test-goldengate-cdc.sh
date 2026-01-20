#!/bin/bash

# Oracle GoldenGate CDC Test Script
# This script tests the CDC replication from Oracle to PostgreSQL

echo "============================================"
echo "Testing Oracle GoldenGate CDC"
echo "============================================"
echo ""

# Generate random test ID
TEST_ID=$((1000 + RANDOM % 9000))

echo "Step 1: Checking initial row counts..."
echo "--------------------------------------"
ORACLE_COUNT_BEFORE=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
PG_COUNT_BEFORE=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)

echo "Oracle CUSTOMERS: ${ORACLE_COUNT_BEFORE:-Error} rows"
echo "PostgreSQL customers: ${PG_COUNT_BEFORE:-Error} rows"
echo ""

echo "Step 2: Inserting test record in Oracle..."
echo "-------------------------------------------"
echo "Test ID: $TEST_ID"

docker exec oracle-db bash -c "echo 'INSERT INTO ogguser.CUSTOMERS VALUES ($TEST_ID, '\''Test'\'', '\''GoldenGate'\'', '\''test.gg@example.com'\''); COMMIT; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1

echo "✓ Test record inserted in Oracle"
echo ""

echo "Step 3: Waiting 10 seconds for GoldenGate to replicate..."
sleep 10

echo ""
echo "Step 4: Verifying replication in PostgreSQL..."
echo "----------------------------------------------"

PG_RESULT=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT id, first_name, last_name, email FROM public.customers WHERE id = $TEST_ID;" 2>/dev/null)

if [ -z "$PG_RESULT" ]; then
    echo "✗ FAILED: Record not found in PostgreSQL"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check GoldenGate status: ./monitor-goldengate.sh"
    echo "  2. Check Oracle connectivity: docker exec oracle-db sqlplus system/oracle@//localhost:1521/XE"
    echo "  3. Check PostgreSQL connectivity: docker exec postgres-db psql -U postgres -d postgres"
    echo "  4. Check container status: docker-compose ps"
    echo "  5. Check GoldenGate services are running: docker exec goldengate-oracle ps aux"
    echo "  6. Review README.md for web UI configuration steps"
    echo ""
    echo "Note: GoldenGate Free Edition requires web UI configuration to start CDC processes:"
    echo "  - Oracle Extract: http://localhost:9100"
    echo "  - PostgreSQL Replicat: http://localhost:9200"
    echo "  - Default credentials: oggadmin / Welcome1"
    exit 1
else
    echo "✓ SUCCESS: Record replicated to PostgreSQL"
    echo "Data: $PG_RESULT"
fi

echo ""
echo "Step 5: Checking final row counts..."
echo "------------------------------------"
ORACLE_COUNT_AFTER=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
PG_COUNT_AFTER=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)

echo "Oracle CUSTOMERS: ${ORACLE_COUNT_AFTER:-Error} rows"
echo "PostgreSQL customers: ${PG_COUNT_AFTER:-Error} rows"

if [ -n "$ORACLE_COUNT_BEFORE" ] && [ -n "$ORACLE_COUNT_AFTER" ] && [ "$ORACLE_COUNT_BEFORE" != "Error" ] && [ "$ORACLE_COUNT_AFTER" != "Error" ]; then
    echo "Oracle change: +$((ORACLE_COUNT_AFTER - ORACLE_COUNT_BEFORE))"
fi
if [ -n "$PG_COUNT_BEFORE" ] && [ -n "$PG_COUNT_AFTER" ] && [ "$PG_COUNT_BEFORE" != "Error" ] && [ "$PG_COUNT_AFTER" != "Error" ]; then
    echo "PostgreSQL change: +$((PG_COUNT_AFTER - PG_COUNT_BEFORE))"
fi

echo ""
echo "============================================"
echo "GoldenGate CDC Test Complete!"
echo "============================================"
echo ""
echo "Manual testing examples:"
echo ""
echo "Test UPDATE operations:"
echo "  docker exec oracle-db bash -c \"echo 'UPDATE ogguser.CUSTOMERS SET FIRST_NAME='\''Updated'\'' WHERE ID=$TEST_ID; COMMIT; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE\""
echo ""
echo "Test DELETE operations:"
echo "  docker exec oracle-db bash -c \"echo 'DELETE FROM ogguser.CUSTOMERS WHERE ID=$TEST_ID; COMMIT; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE\""
echo ""
echo "Monitor replication:"
echo "  ./monitor-goldengate.sh"
echo ""

