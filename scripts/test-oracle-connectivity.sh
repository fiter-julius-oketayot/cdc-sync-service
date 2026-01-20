#!/bin/bash

# Quick Oracle Database Test
# This script performs a simple connectivity test to Oracle

echo "============================================"
echo "Quick Oracle Database Test"
echo "============================================"

# Test basic connectivity
echo "Testing Oracle connectivity..."
if docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1; then
    echo "✓ Oracle connectivity test passed"
else
    echo "✗ Oracle connectivity test failed"
    echo "Run: ./00-check-oracle-startup.sh to diagnose"
    exit 1
fi

# Test database status
echo "Checking database status..."
STATUS=$(docker exec oracle-db bash -c "echo 'SELECT status FROM v\$instance;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | tail -1 | tr -d ' \r\n')

if [ "$STATUS" = "OPEN" ]; then
    echo "✓ Database status: OPEN"
else
    echo "✗ Database status: $STATUS (expected: OPEN)"
    echo "Run: ./00-check-oracle-startup.sh to fix"
    exit 1
fi

echo "✓ Oracle Database is ready for setup!"
echo "============================================"
