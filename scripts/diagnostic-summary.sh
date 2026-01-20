#!/bin/bash

# Simple diagnostic script for Oracle GoldenGate setup
echo "============================================"
echo "GoldenGate Diagnostic Summary"
echo "============================================"
echo ""

echo "1. Container Status:"
echo "-------------------"
if docker ps | grep -q oracle-db; then
    echo "✓ Oracle Database container running"
else
    echo "✗ Oracle Database container not running"
fi

if docker ps | grep -q postgres-db; then
    echo "✓ PostgreSQL Database container running"
else
    echo "✗ PostgreSQL Database container not running"
fi

if docker ps | grep -q goldengate-oracle; then
    echo "✓ GoldenGate Oracle container running"
else
    echo "✗ GoldenGate Oracle container not running"
fi

if docker ps | grep -q goldengate-postgres; then
    echo "✓ GoldenGate PostgreSQL container running"
else
    echo "✗ GoldenGate PostgreSQL container not running"
fi

echo ""
echo "2. Oracle Database Status:"
echo "---------------------------"
# Test Oracle database connectivity
if docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1; then
    echo "✓ Oracle database accessible"

    # Check if OGGUSER exists
    USER_COUNT=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME='\''OGGUSER'\''; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
    if [ "$USER_COUNT" = "1" ]; then
        echo "✓ OGGUSER user exists"

        # Check if table exists
        TABLE_COUNT=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER='\''OGGUSER'\'' AND TABLE_NAME='\''CUSTOMERS'\''; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
        if [ "$TABLE_COUNT" = "1" ]; then
            echo "✓ OGGUSER.CUSTOMERS table exists"

            # Check row count
            ROW_COUNT=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
            echo "✓ CUSTOMERS table has ${ROW_COUNT:-Unknown} rows"
        else
            echo "✗ OGGUSER.CUSTOMERS table does not exist"
        fi
    else
        echo "✗ OGGUSER user does not exist"
    fi
else
    echo "✗ Oracle database not accessible"
fi

echo ""
echo "3. PostgreSQL Database Status:"
echo "-------------------------------"
if docker exec postgres-db psql -U postgres -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✓ PostgreSQL database accessible"

    POSTGRES_ROWS=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)
    echo "✓ PostgreSQL customers table has ${POSTGRES_ROWS:-Unknown} rows"
else
    echo "✗ PostgreSQL database not accessible"
fi

echo ""
echo "4. GoldenGate Services Status:"
echo "-------------------------------"
ORACLE_SERVICES=$(docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")
POSTGRES_SERVICES=$(docker exec goldengate-postgres bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")

echo "Oracle GoldenGate services: $ORACLE_SERVICES/4"
echo "PostgreSQL GoldenGate services: $POSTGRES_SERVICES/4"

if [ "$ORACLE_SERVICES" = "4" ] && [ "$POSTGRES_SERVICES" = "4" ]; then
    echo "✓ All GoldenGate services running"
else
    echo "⚠ Some GoldenGate services may be missing"
fi

echo ""
echo "5. CDC Configuration Status:"
echo "-----------------------------"
echo "❌ Extract process: Not configured (requires web UI)"
echo "❌ Replicat process: Not configured (requires web UI)"
echo "❌ Trail files: Not set up (requires web UI)"
echo "❌ Active replication: Not started"

echo ""
echo "6. Next Steps Required:"
echo "-----------------------"
echo "1. Configure via Oracle GoldenGate Web UI:"
echo "   http://localhost:9100 (Oracle Extract)"
echo "   http://localhost:9200 (PostgreSQL Replicat)"
echo ""
echo "2. Default credentials: oggadmin / Welcome1"
echo ""
echo "3. Follow the README.md configuration guide"

echo ""
echo "============================================"
echo "Status: Infrastructure Ready - Web Configuration Required"
echo "============================================"
