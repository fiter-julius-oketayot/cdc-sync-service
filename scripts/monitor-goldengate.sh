#!/bin/bash

# Oracle GoldenGate Monitoring Script (Free Edition)
# This script monitors GoldenGate Free Edition services and processes

echo "============================================"
echo "Oracle GoldenGate Status Monitor (Free Edition)"
echo "============================================"
echo ""

echo "Checking Oracle GoldenGate Services..."
echo "-------------------------------------------"
echo "Oracle GoldenGate Container Services:"
if docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr|extract|replicat' | grep -v grep"; then
    echo "✓ GoldenGate services are running"
else
    echo "✗ No GoldenGate services detected"
fi

echo ""
echo "PostgreSQL GoldenGate Container Services:"
if docker exec goldengate-postgres bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr|extract|replicat' | grep -v grep"; then
    echo "✓ PostgreSQL GoldenGate services are running"
else
    echo "✗ No PostgreSQL GoldenGate services detected"
fi

echo ""
echo "Checking GoldenGate Processes Status..."
echo "-------------------------------------------"
echo "Oracle Extract/Pump processes:"
docker exec goldengate-oracle bash -c "ps aux | grep -E 'extract|pump' | grep -v grep | awk '{print \$11, \$12, \$13}'" || echo "No extract/pump processes found"

echo ""
echo "PostgreSQL Replicat processes:"
docker exec goldengate-postgres bash -c "ps aux | grep replicat | grep -v grep | awk '{print \$11, \$12, \$13}'" || echo "No replicat processes found"

echo ""
echo "Checking Trail Files..."
echo "-------------------------------------------"
echo "Oracle Trail Files:"
if docker exec goldengate-oracle test -d /opt/oracle/ogg/dirdat 2>/dev/null; then
    docker exec goldengate-oracle ls -lh /opt/oracle/ogg/dirdat/ 2>/dev/null || echo "Directory exists but empty"
else
    echo "Trail directory not created yet (normal for Free Edition)"
fi

echo ""
echo "PostgreSQL Trail Files:"
if docker exec goldengate-postgres test -d /opt/oracle/ogg/dirdat 2>/dev/null; then
    docker exec goldengate-postgres ls -lh /opt/oracle/ogg/dirdat/ 2>/dev/null || echo "Directory exists but empty"
else
    echo "Trail directory not created yet (normal for Free Edition)"
fi

echo ""
echo "Checking Configuration Files..."
echo "-------------------------------------------"
echo "Oracle Parameter Files:"
if docker exec goldengate-oracle test -d /opt/oracle/ogg/dirprm 2>/dev/null; then
    docker exec goldengate-oracle ls -la /opt/oracle/ogg/dirprm/ 2>/dev/null || echo "No parameter files found"
else
    echo "Parameter directory not created yet (will be configured via web UI)"
fi

echo ""
echo "PostgreSQL Parameter Files:"
if docker exec goldengate-postgres test -d /opt/oracle/ogg/dirprm 2>/dev/null; then
    docker exec goldengate-postgres ls -la /opt/oracle/ogg/dirprm/ 2>/dev/null || echo "No parameter files found"
else
    echo "Parameter directory not created yet (will be configured via web UI)"
fi

echo ""
echo "Checking Database Row Counts..."
echo "-------------------------------------------"
echo "Oracle CUSTOMERS count:"
ORACLE_COUNT=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
echo "  Oracle: ${ORACLE_COUNT:-Error connecting}"

echo ""
echo "PostgreSQL customers count:"
POSTGRES_COUNT=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)
echo "  PostgreSQL: ${POSTGRES_COUNT:-Error connecting}"

echo ""
echo "Data Synchronization Status:"
if [ "${ORACLE_COUNT:-0}" = "${POSTGRES_COUNT:-0}" ] && [ "${ORACLE_COUNT:-0}" != "0" ]; then
    echo "✓ Row counts match: Oracle=$ORACLE_COUNT, PostgreSQL=$POSTGRES_COUNT"
else
    echo "⚠ Row counts differ: Oracle=${ORACLE_COUNT:-0}, PostgreSQL=${POSTGRES_COUNT:-0}"
fi

echo ""
echo "Recent GoldenGate Logs..."
echo "-------------------------------------------"
echo "Oracle GoldenGate container logs (last 10 lines):"
docker logs goldengate-oracle --tail=10 2>/dev/null | grep -E "(ERROR|WARN|INFO)" | tail -5 || echo "No recent log entries"

echo ""
echo "PostgreSQL GoldenGate container logs (last 10 lines):"
docker logs goldengate-postgres --tail=10 2>/dev/null | grep -E "(ERROR|WARN|INFO)" | tail -5 || echo "No recent log entries"

echo ""
echo "============================================"
echo "Monitor Complete"
echo "============================================"

