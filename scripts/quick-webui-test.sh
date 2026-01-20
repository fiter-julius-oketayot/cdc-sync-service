#!/bin/bash

# Simple GoldenGate Web UI Test Script - Bash Version
# This is a simplified, working version for quick testing

echo ""
echo "============================================"
echo "Simple GoldenGate Web UI Test"
echo "============================================"
echo ""

# Change to project directory
cd "$(dirname "$0")/.." || exit 1

echo "Step 1: Checking container status..."
containers=$(docker ps --filter "name=goldengate" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
if [ -n "$containers" ]; then
    echo "Current containers:"
    echo "$containers"
else
    echo "No GoldenGate containers running"
fi

echo ""
echo "Step 2: Testing web UI ports..."

# Test Oracle GoldenGate Web UI
echo "Testing Oracle GoldenGate Web UI (localhost:9100):"
if curl -s -I --connect-timeout 5 http://localhost:9100 >/dev/null 2>&1; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:9100)
    echo "✓ Oracle GoldenGate Web UI is accessible (HTTP $http_code)"
else
    echo "✗ Oracle GoldenGate Web UI not accessible"
fi

# Test PostgreSQL GoldenGate Web UI
echo ""
echo "Testing PostgreSQL GoldenGate Web UI (localhost:9200):"
if curl -s -I --connect-timeout 5 http://localhost:9200 >/dev/null 2>&1; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:9200)
    echo "✓ PostgreSQL GoldenGate Web UI is accessible (HTTP $http_code)"
else
    echo "✗ PostgreSQL GoldenGate Web UI not accessible"
fi

echo ""
echo "Step 3: Port mapping verification..."
echo "Oracle GoldenGate port mappings:"
oracle_ports=$(docker port goldengate-oracle 2>/dev/null)
if [ -n "$oracle_ports" ]; then
    echo "$oracle_ports" | sed 's/^/  /'
else
    echo "  No Oracle container or ports found"
fi

echo ""
echo "PostgreSQL GoldenGate port mappings:"
postgres_ports=$(docker port goldengate-postgres 2>/dev/null)
if [ -n "$postgres_ports" ]; then
    echo "$postgres_ports" | sed 's/^/  /'
else
    echo "  No PostgreSQL container or ports found"
fi

echo ""
echo "Step 4: Quick restart (if needed)..."
echo -n "Do you want to restart the GoldenGate containers? (y/n): "
read -r restart_choice

if [ "$restart_choice" = "y" ] || [ "$restart_choice" = "Y" ]; then
    echo "Restarting containers..."
    docker-compose restart goldengate-oracle goldengate-postgres

    echo "Waiting 60 seconds for services to start..."
    for i in {1..60}; do
        echo -ne "Restarting... $i/60 seconds\r"
        sleep 1
    done
    echo ""

    # Test again after restart
    echo ""
    echo "Testing after restart..."
    if curl -s -I --connect-timeout 5 http://localhost:9100 >/dev/null 2>&1; then
        echo "✓ Oracle Web UI now accessible"
    else
        echo "✗ Oracle Web UI still not accessible"
    fi

    if curl -s -I --connect-timeout 5 http://localhost:9200 >/dev/null 2>&1; then
        echo "✓ PostgreSQL Web UI now accessible"
    else
        echo "✗ PostgreSQL Web UI still not accessible"
    fi
fi

echo ""
echo "============================================"
echo "Web UI Access Information:"
echo "============================================"
echo "Oracle GoldenGate:     http://localhost:9100"
echo "PostgreSQL GoldenGate: http://localhost:9200"
echo "Username: oggadmin"
echo "Password: Welcome1"

echo ""
echo "Alternative options:"
echo "1. Create management dashboard: ./create-dashboard.sh"
echo "2. Manual container access: docker exec -it goldengate-oracle bash"
echo "3. Check logs: docker logs goldengate-oracle --tail=20"

echo ""
echo "============================================"
echo ""
