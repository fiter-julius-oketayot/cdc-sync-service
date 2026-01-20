#!/bin/bash

# Simple Web UI Test Script
echo "============================================"
echo "Testing GoldenGate Web UI Access"
echo "============================================"
echo ""

echo "Step 1: Checking Docker containers..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|goldengate)"

echo ""
echo "Step 2: Testing web UI ports..."

echo "Testing Oracle GoldenGate Web UI (localhost:9100):"
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:9100 | grep -q "200\|302\|401"; then
    echo "✓ Oracle Web UI responding"
else
    echo "✗ Oracle Web UI not responding"
fi

echo ""
echo "Testing PostgreSQL GoldenGate Web UI (localhost:9200):"
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:9200 | grep -q "200\|302\|401"; then
    echo "✓ PostgreSQL Web UI responding"
else
    echo "✗ PostgreSQL Web UI not responding"
fi

echo ""
echo "Step 3: Container port mappings..."
echo "Oracle GoldenGate:"
docker port goldengate-oracle 2>/dev/null || echo "Container not running"

echo ""
echo "PostgreSQL GoldenGate:"
docker port goldengate-postgres 2>/dev/null || echo "Container not running"

echo ""
echo "============================================"
echo "Quick Access Links:"
echo "Oracle GoldenGate:     http://localhost:9100"
echo "PostgreSQL GoldenGate: http://localhost:9200"
echo "Username: oggadmin"
echo "Password: Welcome1"
echo "============================================"
