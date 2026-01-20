#!/bin/bash

# Oracle Database Startup and Health Check Script
# This script ensures Oracle Database is fully started and ready for GoldenGate setup

set -e

echo "============================================"
echo "Oracle Database Startup Check"
echo "============================================"
echo ""

# Check if Oracle container is running
if ! docker ps | grep -q oracle-db; then
    echo "✗ Oracle container (oracle-db) is not running!"
    echo "Please start it first with: docker-compose up -d oracle-db"
    exit 1
fi

echo "✓ Oracle container is running"

# Function to check Oracle database status
check_oracle_status() {
    docker exec oracle-db bash -c "echo 'SELECT status FROM v\$instance;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -q "OPEN"
}

# Function to check Oracle connectivity
check_oracle_connectivity() {
    docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1
}

# Function to restart Oracle if needed
restart_oracle_if_needed() {
    echo "Attempting to start Oracle database instance..."

    # First, check if Oracle instance is running
    INSTANCE_STATUS=$(docker exec oracle-db bash -c "echo 'SELECT status FROM v\$instance;' | sqlplus -S / as sysdba 2>/dev/null" | tail -1 2>/dev/null || echo "UNKNOWN")

    echo "Current instance status: $INSTANCE_STATUS"

    if [ "$INSTANCE_STATUS" != "OPEN" ]; then
        echo "Attempting to startup Oracle database..."
        docker exec oracle-db bash -c "
            echo 'STARTUP;' | sqlplus -S / as sysdba
            echo 'ALTER PLUGGABLE DATABASE ALL OPEN;' | sqlplus -S / as sysdba
        " >/dev/null 2>&1 || true

        echo "Waiting 30 seconds for startup to complete..."
        sleep 30
    else
        echo "Instance is already OPEN, checking connectivity..."
    fi
}

echo "Checking Oracle Database status..."

# Wait up to 15 minutes for Oracle to be ready
TIMEOUT=900  # 15 minutes
ELAPSED=0
INTERVAL=15

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Check current status
    CONNECTIVITY_OK=false
    STATUS_OK=false

    if check_oracle_connectivity; then
        CONNECTIVITY_OK=true
        if check_oracle_status; then
            STATUS_OK=true
            echo "✓ Oracle Database is ready and OPEN!"
            break
        fi
    fi

    # Provide detailed status information
    echo "Oracle status check ($ELAPSED/$TIMEOUT seconds):"
    echo "  - Connectivity: $([ "$CONNECTIVITY_OK" = true ] && echo "✓ Connected" || echo "✗ Not connected")"
    echo "  - Database Status: $([ "$STATUS_OK" = true ] && echo "✓ OPEN" || echo "✗ Not open")"

    # Show what Oracle is doing every minute
    if [ $((ELAPSED % 60)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
        echo "  - Checking Oracle container health..."
        if docker exec oracle-db ps aux | grep -q ora_pmon; then
            echo "  - ✓ Oracle processes are running"
        else
            echo "  - ✗ Oracle processes not detected"
        fi

        echo "  - Recent Oracle logs:"
        docker logs oracle-db --tail=5 2>/dev/null | sed 's/^/    /'
    fi

    # Try to restart Oracle if it's been a while
    if [ $ELAPSED -gt 180 ] && [ $((ELAPSED % 180)) -eq 0 ]; then
        echo "  - Attempting to restart Oracle database instance..."
        restart_oracle_if_needed
    fi

    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))

    # Check if container is still running
    if ! docker ps | grep -q oracle-db; then
        echo "✗ Oracle container stopped unexpectedly!"
        echo "Check container logs: docker logs oracle-db"
        exit 1
    fi
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "✗ Timeout: Oracle Database did not start within 15 minutes"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check Oracle container logs: docker logs oracle-db"
    echo "2. Try restarting the container: docker-compose restart oracle-db"
    echo "3. Check available memory and disk space"
    echo ""
    exit 1
fi

echo ""
echo "Oracle Database Status:"
docker exec oracle-db bash -c "echo 'SELECT instance_name, status FROM v\$instance;' | sqlplus -S system/oracle@//localhost:1521/XE"

echo ""
echo "✓ Oracle Database is ready for GoldenGate setup!"
echo "============================================"
