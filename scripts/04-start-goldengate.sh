#!/bin/bash

# Oracle GoldenGate Start Script (Free Edition)
# This script verifies that GoldenGate Free Edition services are running

set -e

echo "============================================"
echo "Starting Oracle GoldenGate Processes (Free Edition)"
echo "============================================"
echo ""

echo "Step 1: Verifying Oracle GoldenGate services..."
echo "Oracle GoldenGate Container:"
if docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep" >/dev/null; then
    echo "✓ GoldenGate services are running"
    docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | awk '{print \"  -\", \$11, \$12}'"
else
    echo "✗ GoldenGate services not running"
    echo "Attempting to restart container..."
    docker-compose restart goldengate-oracle
    echo "Waiting 60 seconds for services to start..."
    sleep 60
fi

echo ""
echo "Step 2: Verifying PostgreSQL GoldenGate services..."
echo "PostgreSQL GoldenGate Container:"
if docker exec goldengate-postgres bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep" >/dev/null; then
    echo "✓ PostgreSQL GoldenGate services are running"
    docker exec goldengate-postgres bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | awk '{print \"  -\", \$11, \$12}'"
else
    echo "✗ PostgreSQL GoldenGate services not running"
    echo "Attempting to restart container..."
    docker-compose restart goldengate-postgres
    echo "Waiting 60 seconds for services to start..."
    sleep 60
fi

echo ""
echo "Step 3: Checking connectivity between services..."
echo "Testing Oracle database connectivity..."
if docker exec oracle-db sqlplus -S ogguser/oggpassword@//localhost:1521/XE << 'EOF'
SELECT 'Oracle DB: ' || COUNT(*) || ' customers' FROM CUSTOMERS;
EXIT;
EOF
then
    echo "✓ Oracle database accessible"
else
    echo "✗ Oracle database connectivity failed"
fi

echo ""
echo "Testing PostgreSQL database connectivity..."
if docker exec postgres-db psql -U postgres -d postgres -c "SELECT 'PostgreSQL DB: ' || COUNT(*) || ' customers' FROM public.customers;" 2>/dev/null; then
    echo "✓ PostgreSQL database accessible"
else
    echo "✗ PostgreSQL database connectivity failed"
fi

echo ""
echo "Step 4: Final status check..."
echo ""
echo "GoldenGate Free Edition Service Summary:"
echo "========================================="

echo ""
echo "Oracle GoldenGate Container Services:"
docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" | awk '{print "  Active services: " $1}'

echo ""
echo "PostgreSQL GoldenGate Container Services:"
docker exec goldengate-postgres bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" | awk '{print "  Active services: " $1}'

echo ""
echo "============================================"
echo "GoldenGate Free Edition Status Complete!"
echo "============================================"
echo ""
echo "Note: GoldenGate Free Edition uses automatic service management."
echo "Traditional Extract/Pump/Replicat processes are managed by the"
echo "service layer and may not appear as separate processes."
echo ""
echo "To monitor the system:"
echo "  ./monitor-goldengate.sh"
echo ""
echo "To test data replication:"
echo "  ./test-goldengate-cdc.sh"
echo ""

