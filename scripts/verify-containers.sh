#!/bin/bash

# Quick container verification script
# This script checks that all containers are running with the correct names

echo "============================================"
echo "Container Status Verification"
echo "============================================"
echo ""

echo "Checking required containers..."
echo "-------------------------------"

# Array of required containers
containers=("oracle-db" "postgres-db" "goldengate-oracle" "goldengate-postgres")

all_running=true

for container in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        STATUS=$(docker ps --filter "name=${container}" --format "{{.Status}}")
        echo "✓ ${container}: ${STATUS}"
    else
        echo "✗ ${container}: Not running"
        all_running=false
    fi
done

echo ""
echo "Network Connectivity Test:"
echo "---------------------------"

# Test Oracle Database
if docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1; then
    echo "✓ Oracle Database: Accessible"
else
    echo "✗ Oracle Database: Connection failed"
    all_running=false
fi

# Test PostgreSQL Database
if docker exec postgres-db psql -U postgres -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✓ PostgreSQL Database: Accessible"
else
    echo "✗ PostgreSQL Database: Connection failed"
    all_running=false
fi

# Test GoldenGate Oracle Services
ORACLE_SERVICES=$(docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")
if [ "$ORACLE_SERVICES" = "4" ]; then
    echo "✓ GoldenGate Oracle: 4/4 services running"
else
    echo "⚠ GoldenGate Oracle: ${ORACLE_SERVICES}/4 services running"
    all_running=false
fi

# Test GoldenGate PostgreSQL Services
POSTGRES_SERVICES=$(docker exec goldengate-postgres bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")
if [ "$POSTGRES_SERVICES" = "4" ]; then
    echo "✓ GoldenGate PostgreSQL: 4/4 services running"
else
    echo "⚠ GoldenGate PostgreSQL: ${POSTGRES_SERVICES}/4 services running"
    all_running=false
fi

echo ""
echo "Web UI Accessibility Test:"
echo "---------------------------"

# Test Oracle GoldenGate Web UI
if curl -s --connect-timeout 5 http://localhost:9100 >/dev/null 2>&1; then
    echo "✓ Oracle GoldenGate Web UI: Accessible at http://localhost:9100"
else
    echo "✗ Oracle GoldenGate Web UI: Not accessible (may still be starting)"
    all_running=false
fi

# Test PostgreSQL GoldenGate Web UI
if curl -s --connect-timeout 5 http://localhost:9200 >/dev/null 2>&1; then
    echo "✓ PostgreSQL GoldenGate Web UI: Accessible at http://localhost:9200"
else
    echo "✗ PostgreSQL GoldenGate Web UI: Not accessible (may still be starting)"
    all_running=false
fi

echo ""
echo "Port Status:"
echo "------------"
echo "Oracle Database: Port 1521 → $(docker port oracle-db 1521 2>/dev/null || echo 'Not exposed')"
echo "PostgreSQL Database: Port 5434 → $(docker port postgres-db 5432 2>/dev/null || echo 'Not exposed')"
echo "GoldenGate Oracle Web UI: Port 9100 → $(docker port goldengate-oracle 9100 2>/dev/null || echo 'Not exposed')"
echo "GoldenGate PostgreSQL Web UI: Port 9200 → $(docker port goldengate-postgres 9100 2>/dev/null || echo 'Not exposed')"

echo ""
echo "============================================"
if [ "$all_running" = true ]; then
    echo "✅ STATUS: ALL SYSTEMS READY"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure CDC via Web UI:"
    echo "     - Oracle Extract: http://localhost:9100"
    echo "     - PostgreSQL Replicat: http://localhost:9200"
    echo "     - Credentials: oggadmin / Welcome1"
    echo ""
    echo "  2. Test CDC after configuration:"
    echo "     ./test-goldengate-cdc.sh"
    echo ""
    echo "  3. Monitor replication:"
    echo "     ./monitor-goldengate.sh"
else
    echo "❌ STATUS: ISSUES DETECTED"
    echo ""
    echo "Troubleshooting Steps:"
    echo "  1. Start all containers: docker-compose up -d"
    echo "  2. Check container logs: docker logs <container-name>"
    echo "  3. Verify docker-compose.yml configuration"
    echo "  4. Ensure sufficient system resources (8GB RAM recommended)"
    echo ""
    echo "For Web UI Issues:"
    echo "  1. Run setup script: ./setup-webui.sh"
    echo "  2. Run diagnostics: ./troubleshoot-webui.sh"
    echo "  3. Wait 2-3 minutes after container restart"
    echo "  4. Check if Oracle login is required: docker login container-registry.oracle.com"
fi
echo "============================================"
