#!/bin/bash

# Simple CDC Test Script for GoldenGate Free Edition
# This script tests if data changes are replicated from Oracle to PostgreSQL

echo "============================================"
echo "GoldenGate CDC Test"
echo "============================================"
echo ""

echo "Step 1: Checking initial data..."
echo "Oracle CUSTOMERS table:"
ORACLE_BEFORE=$(docker exec oracle-db sqlplus -S system/oracle@//localhost:1521/XE << 'EOF'
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM ogguser.CUSTOMERS;
EXIT;
EOF
)

echo "PostgreSQL customers table:"
POSTGRES_BEFORE=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)

echo "  Oracle: ${ORACLE_BEFORE:-Error} rows"
echo "  PostgreSQL: ${POSTGRES_BEFORE:-Error} rows"

echo ""
echo "Step 2: Inserting test record in Oracle..."

# Generate a random ID to avoid conflicts
TEST_ID=$((1000 + RANDOM % 9000))

docker exec oracle-db sqlplus -S system/oracle@//localhost:1521/XE << EOF
INSERT INTO ogguser.CUSTOMERS VALUES ($TEST_ID, 'Test', 'User', 'test$TEST_ID@example.com');
COMMIT;
EXIT;
EOF

if [ $? -eq 0 ]; then
    echo "✓ Test record inserted with ID: $TEST_ID"
else
    echo "✗ Failed to insert test record"
    exit 1
fi

echo ""
echo "Step 3: Waiting for replication (30 seconds)..."
sleep 30

echo ""
echo "Step 4: Checking if record was replicated..."

echo "Oracle CUSTOMERS table:"
ORACLE_AFTER=$(docker exec oracle-db sqlplus -S system/oracle@//localhost:1521/XE << 'EOF'
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM ogguser.CUSTOMERS;
EXIT;
EOF
)

echo "PostgreSQL customers table:"
POSTGRES_AFTER=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)

echo "  Oracle: ${ORACLE_AFTER:-Error} rows"
echo "  PostgreSQL: ${POSTGRES_AFTER:-Error} rows"

echo ""
echo "Checking if test record exists in PostgreSQL:"
POSTGRES_TEST=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers WHERE id = $TEST_ID;" 2>/dev/null)

if [ "$POSTGRES_TEST" = "1" ]; then
    echo "✓ Test record found in PostgreSQL!"
    echo "✓ CDC is working correctly"

    # Show the replicated record
    echo ""
    echo "Replicated record details:"
    docker exec postgres-db psql -U postgres -d postgres -c "SELECT * FROM public.customers WHERE id = $TEST_ID;" 2>/dev/null
else
    echo "✗ Test record NOT found in PostgreSQL"
    echo "✗ CDC may not be working properly"

    echo ""
    echo "Troubleshooting information:"
    echo "- Check GoldenGate services: ./monitor-goldengate.sh"
    echo "- Check container logs: docker logs goldengate-oracle"
    echo "- Check parameter files in scripts/ogg-oracle/ and scripts/ogg-postgres/"
fi

echo ""
echo "============================================"
echo "CDC Test Complete"
echo "============================================"
