#!/bin/bash

# GoldenGate Web UI Troubleshooting and Setup Script
# This script diagnoses and fixes web UI access issues

echo "============================================"
echo "GoldenGate Web UI Troubleshooting"
echo "============================================"
echo ""

echo "Step 1: Checking container status..."
echo "------------------------------------"
docker ps --filter "name=goldengate" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Step 2: Checking port bindings..."
echo "----------------------------------"
echo "Oracle GoldenGate ports:"
docker port goldengate-oracle 2>/dev/null || echo "Container not running or ports not mapped"

echo ""
echo "PostgreSQL GoldenGate ports:"
docker port goldengate-postgres 2>/dev/null || echo "Container not running or ports not mapped"

echo ""
echo "Step 3: Testing web UI accessibility..."
echo "--------------------------------------"
echo "Testing Oracle GoldenGate Web UI (port 9100):"
if curl -s --connect-timeout 5 http://localhost:9100 >/dev/null 2>&1; then
    echo "✓ Oracle GoldenGate Web UI is accessible"
else
    echo "✗ Oracle GoldenGate Web UI is not accessible"
fi

echo ""
echo "Testing PostgreSQL GoldenGate Web UI (port 9200):"
if curl -s --connect-timeout 5 http://localhost:9200 >/dev/null 2>&1; then
    echo "✓ PostgreSQL GoldenGate Web UI is accessible"
else
    echo "✗ PostgreSQL GoldenGate Web UI is not accessible"
fi

echo ""
echo "Step 4: Checking GoldenGate service processes..."
echo "------------------------------------------------"
echo "Oracle GoldenGate container processes:"
docker exec goldengate-oracle ps aux 2>/dev/null | grep -E "(nginx|ServiceManager|adminsrvr)" | head -5 || echo "Cannot access container or no processes found"

echo ""
echo "PostgreSQL GoldenGate container processes:"
docker exec goldengate-postgres ps aux 2>/dev/null | grep -E "(nginx|ServiceManager|adminsrvr)" | head -5 || echo "Cannot access container or no processes found"

echo ""
echo "Step 5: Checking container logs for errors..."
echo "---------------------------------------------"
echo "Oracle GoldenGate container logs (last 10 lines):"
docker logs goldengate-oracle --tail=10 2>/dev/null || echo "Cannot access container logs"

echo ""
echo "PostgreSQL GoldenGate container logs (last 10 lines):"
docker logs goldengate-postgres --tail=10 2>/dev/null || echo "Cannot access container logs"

echo ""
echo "Step 6: Network port status..."
echo "------------------------------"
netstat -an 2>/dev/null | grep -E ":9100|:9200" || echo "Ports not listening"

echo ""
echo "============================================"
echo "Troubleshooting Complete"
echo "============================================"
echo ""

echo "Common Solutions:"
echo "1. If containers are not running:"
echo "   docker-compose up -d goldengate-oracle goldengate-postgres"
echo ""
echo "2. If ports are not mapped:"
echo "   Check docker-compose.yml ports section"
echo ""
echo "3. If services are not starting:"
echo "   docker-compose restart goldengate-oracle goldengate-postgres"
echo ""
echo "4. If web UI is still not accessible:"
echo "   Try accessing via container IP:"
echo "   docker inspect goldengate-oracle | grep IPAddress"
echo ""
echo "5. Alternative access methods:"
echo "   - Oracle: docker exec -it goldengate-oracle bash"
echo "   - PostgreSQL: docker exec -it goldengate-postgres bash"
echo ""
