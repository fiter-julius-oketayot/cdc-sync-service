#!/bin/bash

# Oracle GoldenGate Complete Setup Script
# This script runs all setup steps in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "Oracle GoldenGate Complete Setup"
echo "============================================"
echo ""

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ ERROR: Docker is not running"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

echo "This script will setup Oracle GoldenGate CDC"
echo "from Oracle to PostgreSQL in 4 steps."
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Step 0: Check Oracle Database Startup
echo ""
echo "=========================================="
echo "STEP 0: Checking Oracle Database Status"
echo "=========================================="
./00-check-oracle-startup.sh

# Step 1: Database Setup
echo ""
echo "=========================================="
echo "STEP 1/4: Setting up Databases"
echo "=========================================="
./01-setup-databases.sh

# Wait for databases to be ready
echo ""
echo "Waiting 30 seconds for databases to stabilize..."
sleep 30

# Step 2: Oracle GoldenGate Setup
echo ""
echo "=========================================="
echo "STEP 2/4: Configuring Oracle GoldenGate (Extract)"
echo "=========================================="
./02-setup-goldengate-oracle.sh

# Step 3: PostgreSQL GoldenGate Setup
echo ""
echo "=========================================="
echo "STEP 3/4: Configuring PostgreSQL GoldenGate (Replicat)"
echo "=========================================="
./03-setup-goldengate-postgres.sh

# Step 4: Start GoldenGate
echo ""
echo "=========================================="
echo "STEP 4/4: Starting GoldenGate Processes"
echo "=========================================="
./04-start-goldengate.sh

# Verify status
echo ""
echo "=========================================="
echo "Verifying Setup"
echo "=========================================="
sleep 5
./monitor-goldengate.sh

# Run test
echo ""
echo "=========================================="
echo "Running CDC Test"
echo "=========================================="
read -p "Press Enter to run test or Ctrl+C to skip..."
./test-goldengate-cdc.sh

echo ""
echo "============================================"
echo "Oracle GoldenGate Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  - Monitor: ./monitor-goldengate.sh"
echo "  - Test: ./test-goldengate-cdc.sh"
echo "  - Stop: ./stop-goldengate.sh"
echo "  - Web UI: http://localhost:9100 (oggadmin/Welcome1)"
echo ""
echo "For bi-directional sync (PostgreSQL → Oracle):"
echo "  Use the Spring Boot application or Debezium"
echo ""

