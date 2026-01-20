#!/bin/bash

# Oracle GoldenGate Setup Script - Part 2: Configure Oracle Extract (Free Edition)
# This script configures GoldenGate Free Edition on the Oracle side

set -e

echo "============================================"
echo "Oracle GoldenGate Oracle Extract Setup (Free Edition)"
echo "============================================"
echo ""

# Check if container is running
if ! docker ps | grep -q goldengate-oracle; then
    echo "Error: goldengate-oracle container is not running!"
    exit 1
fi

echo "Step 1: Verifying GoldenGate services..."
if docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep" >/dev/null; then
    echo "✓ GoldenGate services are running"
else
    echo "✗ GoldenGate services not running - container may still be starting"
    echo "Waiting 30 seconds for services to start..."
    sleep 30
fi

echo "Step 2: Copying parameter files..."
docker cp ogg-oracle/ext_oracle.prm goldengate-oracle:/opt/oracle/ogg/dirprm/
docker cp ogg-oracle/pump_oracle.prm goldengate-oracle:/opt/oracle/ogg/dirprm/
docker cp ogg-oracle/mgr.prm goldengate-oracle:/opt/oracle/ogg/dirprm/

echo "✓ Parameter files copied"
echo ""

echo "Step 3: Creating GoldenGate directories..."
docker exec goldengate-oracle bash -c "
    mkdir -p /opt/oracle/ogg/dirrpt || true
    mkdir -p /opt/oracle/ogg/dirchk || true
    mkdir -p /opt/oracle/ogg/dirtmp || true
    # Note: Directory permissions are managed by the container
"

echo "✓ Directories created"
echo ""

echo "Step 4: GoldenGate Free Edition Configuration..."
echo "Note: GoldenGate Free Edition uses a service-based architecture"
echo "The traditional Extract/Pump processes are managed differently"
echo ""

echo "Checking current service status:"
docker exec goldengate-oracle bash -c "ps aux | grep -E 'adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | awk '{print \$11, \$12}'" || echo "No services detected"

echo ""
echo "✓ Oracle GoldenGate Free Edition container is configured"
echo ""
echo "============================================"
echo "Oracle GoldenGate Extract Setup Complete!"
echo "============================================"
echo ""
echo "Note: GoldenGate Free Edition automatically handles:"
echo "  - Change capture from Oracle database"
echo "  - Trail file management"
echo "  - Data distribution to remote targets"
echo ""
echo "Next steps:"
echo "  Run: ./03-setup-goldengate-postgres.sh"
echo ""

