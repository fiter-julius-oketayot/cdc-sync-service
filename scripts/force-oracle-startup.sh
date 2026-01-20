#!/bin/bash

# Oracle Database Force Startup Script
# This script attempts to force Oracle database startup

set -e

echo "============================================"
echo "Oracle Database Force Startup"
echo "============================================"
echo ""

# Check if Oracle container is running
if ! docker ps | grep -q oracle-db; then
    echo "✗ Oracle container (oracle-db) is not running!"
    echo "Starting Oracle container..."
    docker-compose up -d oracle-db
    echo "Waiting 30 seconds for container to initialize..."
    sleep 30
fi

echo "✓ Oracle container is running"

echo ""
echo "Attempting to start Oracle database instance..."

# Try different startup approaches
echo "1. Attempting normal startup..."
docker exec oracle-db bash -c "
    export ORACLE_SID=XE
    export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
    echo 'STARTUP;' | sqlplus -S / as sysdba
" 2>/dev/null || echo "Normal startup failed or already running"

sleep 15

echo ""
echo "2. Checking current status..."
STATUS=$(docker exec oracle-db bash -c "echo 'SELECT status FROM v\$instance;' | sqlplus -S / as sysdba 2>/dev/null" | tail -1 2>/dev/null || echo "UNKNOWN")
echo "Instance status: $STATUS"

if [ "$STATUS" != "OPEN" ]; then
    echo ""
    echo "3. Attempting to open database..."
    docker exec oracle-db bash -c "
        export ORACLE_SID=XE
        export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
        echo 'ALTER DATABASE OPEN;' | sqlplus -S / as sysdba
    " 2>/dev/null || echo "Database open failed"

    sleep 10
fi

echo ""
echo "4. Opening pluggable databases..."
docker exec oracle-db bash -c "
    export ORACLE_SID=XE
    export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
    echo 'ALTER PLUGGABLE DATABASE ALL OPEN;' | sqlplus -S / as sysdba
" 2>/dev/null || echo "PDB open failed"

sleep 10

echo ""
echo "5. Final status check..."
if docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1; then
    echo "✓ Oracle database is now responding!"

    echo ""
    echo "Database status:"
    docker exec oracle-db bash -c "echo 'SELECT instance_name, status FROM v\$instance;' | sqlplus -S system/oracle@//localhost:1521/XE"
else
    echo "✗ Oracle database is still not responding"
    echo ""
    echo "Try these troubleshooting steps:"
    echo "1. Check container logs: docker logs oracle-db"
    echo "2. Restart container: docker-compose restart oracle-db"
    echo "3. Check available memory (Oracle needs at least 2GB)"
    echo "4. Run diagnostic: ./diagnose-oracle.sh"
fi

echo ""
echo "============================================"
