#!/bin/bash

# GoldenGate Web UI Setup and Restart Script
# This script ensures GoldenGate containers are properly configured for web UI access

echo "============================================"
echo "GoldenGate Web UI Setup"
echo "============================================"
echo ""

echo "Step 1: Stopping existing GoldenGate containers..."
docker-compose down goldengate-oracle goldengate-postgres 2>/dev/null
echo "✓ Containers stopped"

echo ""
echo "Step 2: Removing existing containers (if any)..."
docker rm -f goldengate-oracle goldengate-postgres 2>/dev/null || echo "No containers to remove"

echo ""
echo "Step 3: Starting GoldenGate containers with proper configuration..."
docker-compose up -d goldengate-oracle goldengate-postgres

echo ""
echo "Step 4: Waiting 60 seconds for services to initialize..."
for i in {1..60}; do
    printf "."
    sleep 1
done
echo ""

echo ""
echo "Step 5: Verifying container status..."
docker ps --filter "name=goldengate" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Step 6: Checking port accessibility..."
echo "Testing port 9100 (Oracle GoldenGate):"
if curl -s --connect-timeout 5 http://localhost:9100 >/dev/null 2>&1; then
    echo "✓ Oracle GoldenGate Web UI is accessible at http://localhost:9100"
else
    echo "⚠ Oracle GoldenGate Web UI may still be starting or not accessible"
fi

echo ""
echo "Testing port 9200 (PostgreSQL GoldenGate):"
if curl -s --connect-timeout 5 http://localhost:9200 >/dev/null 2>&1; then
    echo "✓ PostgreSQL GoldenGate Web UI is accessible at http://localhost:9200"
else
    echo "⚠ PostgreSQL GoldenGate Web UI may still be starting or not accessible"
fi

echo ""
echo "Step 7: Web UI Access Information..."
echo "-----------------------------------"
echo "Oracle GoldenGate Web UI:"
echo "  URL: http://localhost:9100"
echo "  Username: oggadmin"
echo "  Password: Welcome1"
echo ""
echo "PostgreSQL GoldenGate Web UI:"
echo "  URL: http://localhost:9200"
echo "  Username: oggadmin"
echo "  Password: Welcome1"
echo ""

echo "============================================"
echo "Setup Complete!"
echo "============================================"
echo ""
echo "If the web UIs are not accessible immediately:"
echo "1. Wait a few more minutes for services to fully start"
echo "2. Check container logs: docker logs goldengate-oracle"
echo "3. Run troubleshooting: ./troubleshoot-webui.sh"
echo ""
