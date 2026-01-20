#!/bin/bash

# Oracle Database Diagnostic Script
# This script helps diagnose Oracle startup issues

echo "============================================"
echo "Oracle Database Diagnostic"
echo "============================================"
echo ""

# Check container status
echo "1. Container Status:"
if docker ps | grep -q oracle-db; then
    echo "✓ Oracle container is running"
    UPTIME=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep oracle-db | awk '{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}')
    echo "   Container uptime: $UPTIME"
else
    echo "✗ Oracle container is not running"
    exit 1
fi

echo ""
echo "2. Container Resources:"
docker exec oracle-db bash -c "
    echo 'Memory usage:';
    free -h;
    echo '';
    echo 'Disk usage:';
    df -h | grep -E '(Filesystem|/opt/oracle)';
"

echo ""
echo "3. Oracle Processes:"
if docker exec oracle-db ps aux | grep -E 'ora_|tnslsnr' | grep -v grep; then
    echo "✓ Oracle processes detected"
else
    echo "✗ No Oracle processes found"
fi

echo ""
echo "4. Recent Oracle Logs (last 20 lines):"
docker logs oracle-db --tail=20 2>/dev/null

echo ""
echo "5. Oracle Connectivity Test:"
if docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1; then
    echo "✓ Oracle responds to SQL queries"

    echo ""
    echo "6. Database Status:"
    docker exec oracle-db bash -c "echo 'SELECT instance_name, status, database_status FROM v\$instance;' | sqlplus -S system/oracle@//localhost:1521/XE"

    echo ""
    echo "7. Database Information:"
    docker exec oracle-db bash -c "echo 'SELECT name, open_mode FROM v\$database;' | sqlplus -S system/oracle@//localhost:1521/XE"

    echo ""
    echo "8. Pluggable Databases:"
    docker exec oracle-db bash -c "echo 'SELECT name, open_mode FROM v\$pdbs;' | sqlplus -S system/oracle@//localhost:1521/XE"

else
    echo "✗ Oracle does not respond to SQL queries"
    echo ""
    echo "6. Attempting to connect as SYSDBA:"
    docker exec oracle-db bash -c "echo 'SELECT status FROM v\$instance;' | sqlplus -S / as sysdba" 2>&1 | head -5
fi

echo ""
echo "9. Listener Status:"
docker exec oracle-db bash -c "lsnrctl status" 2>/dev/null | head -10 || echo "Listener not responding"

echo ""
echo "============================================"
echo "Diagnostic Complete"
echo "============================================"
