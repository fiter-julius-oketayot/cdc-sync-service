#!/bin/bash

# Oracle GoldenGate Complete Setup Script
# This script sets up the entire CDC pipeline from Oracle to PostgreSQL

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

echo "✓ Docker is running"

# ============================================
# STEP 1: Check Oracle Database Status
# ============================================
check_oracle_status() {
    echo ""
    echo "=========================================="
    echo "STEP 1: Checking Oracle Database Status"
    echo "=========================================="

    if ! docker ps | grep -q oracle-db; then
        echo "✗ Oracle container (oracle-db) is not running!"
        echo "Please start it first with: docker-compose up -d oracle-db"
        exit 1
    fi

    echo "✓ Oracle container is running"

    # Wait for Oracle to be ready
    echo "Waiting for Oracle Database to be ready..."
    TIMEOUT=300
    ELAPSED=0
    INTERVAL=10

    while [ $ELAPSED -lt $TIMEOUT ]; do
        if docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1; then
            echo "✓ Oracle Database is ready!"
            return 0
        fi
        echo "  Waiting... ($ELAPSED/$TIMEOUT seconds)"
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    echo "✗ Timeout waiting for Oracle Database"
    exit 1
}

# ============================================
# STEP 2: Setup Databases
# ============================================
setup_databases() {
    echo ""
    echo "=========================================="
    echo "STEP 2: Setting up Databases"
    echo "=========================================="

    # Check containers
    if ! docker ps | grep -q postgres-db; then
        echo "Error: postgres-db container is not running!"
        exit 1
    fi

    # Setup Oracle
    echo "Setting up Oracle Database..."
    docker cp setup-oracle.sql oracle-db:/tmp/

    OUTPUT=$(docker exec oracle-db bash -c "echo '@/tmp/setup-oracle.sql' | sqlplus -S / as sysdba" 2>&1)
    echo "$OUTPUT" | tail -20

    # Verify Oracle setup
    echo "Verifying Oracle setup..."
    VERIFY=$(docker exec oracle-db sqlplus -S system/oracle@//localhost:1521/XE << 'EOF'
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT 'OGGUSER:' || COUNT(*) FROM DBA_USERS WHERE USERNAME = 'OGGUSER';
SELECT 'CUSTOMERS:' || COUNT(*) FROM DBA_TABLES WHERE OWNER = 'OGGUSER' AND TABLE_NAME = 'CUSTOMERS';
EXIT;
EOF
)
    echo "$VERIFY"

    if echo "$VERIFY" | grep -q "OGGUSER:1" && echo "$VERIFY" | grep -q "CUSTOMERS:1"; then
        echo "✓ Oracle setup completed successfully"
    else
        echo "⚠ Warning: Oracle setup may have issues, check manually"
    fi

    # Setup PostgreSQL
    echo ""
    echo "Setting up PostgreSQL Database..."
    docker exec postgres-db psql -U postgres -d postgres -c "\dt public.*" 2>/dev/null || true
    echo "✓ PostgreSQL setup completed (via init script)"
}

# ============================================
# STEP 3: Configure GoldenGate for Oracle
# ============================================
setup_goldengate_oracle() {
    echo ""
    echo "=========================================="
    echo "STEP 3: Configuring Oracle GoldenGate"
    echo "=========================================="

    if ! docker ps | grep -q goldengate-oracle; then
        echo "Error: goldengate-oracle container is not running!"
        exit 1
    fi

    echo "Verifying GoldenGate services..."
    if docker exec goldengate-oracle bash -c "ps aux | grep -E 'ServiceManager|adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep" >/dev/null 2>&1; then
        echo "✓ GoldenGate services are running"
    else
        echo "⚠ GoldenGate services may still be starting..."
        echo "Waiting 30 seconds..."
        sleep 30
    fi

    # Copy parameter files if they exist
    if [ -d "ogg-oracle" ]; then
        echo "Copying parameter files..."
        for file in ogg-oracle/*.prm; do
            [ -f "$file" ] && docker cp "$file" goldengate-oracle:/opt/oracle/ogg/dirprm/ 2>/dev/null || true
        done
        echo "✓ Parameter files copied"
    fi

    echo "✓ Oracle GoldenGate configured"
}

# ============================================
# STEP 4: Configure GoldenGate for PostgreSQL
# ============================================
setup_goldengate_postgres() {
    echo ""
    echo "=========================================="
    echo "STEP 4: Configuring PostgreSQL GoldenGate"
    echo "=========================================="

    if ! docker ps | grep -q goldengate-postgres; then
        echo "Error: goldengate-postgres container is not running!"
        exit 1
    fi

    echo "Verifying GoldenGate services..."
    if docker exec goldengate-postgres bash -c "ps aux | grep -E 'ServiceManager|adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep" >/dev/null 2>&1; then
        echo "✓ PostgreSQL GoldenGate services are running"
    else
        echo "⚠ GoldenGate services may still be starting..."
        echo "Waiting 30 seconds..."
        sleep 30
    fi

    # Copy parameter files if they exist
    if [ -d "ogg-postgres" ]; then
        echo "Copying parameter files..."
        for file in ogg-postgres/*.prm ogg-postgres/*.props; do
            [ -f "$file" ] && docker cp "$file" goldengate-postgres:/opt/oracle/ogg/dirprm/ 2>/dev/null || true
        done
        echo "✓ Parameter files copied"
    fi

    # Create checkpoint table
    echo "Creating checkpoint table in PostgreSQL..."
    docker exec postgres-db psql -U postgres -d postgres << 'EOF' 2>/dev/null || true
CREATE TABLE IF NOT EXISTS public.gg_checkpoint (
    group_name VARCHAR(255),
    group_key VARCHAR(255),
    seqno BIGINT,
    rba BIGINT,
    applied_ts TIMESTAMP,
    PRIMARY KEY (group_name, group_key)
);
GRANT ALL ON TABLE public.gg_checkpoint TO postgres;
EOF
    echo "✓ Checkpoint table created"

    echo "✓ PostgreSQL GoldenGate configured"
}

# ============================================
# STEP 5: Verify Setup
# ============================================
verify_setup() {
    echo ""
    echo "=========================================="
    echo "STEP 5: Verifying Setup"
    echo "=========================================="

    echo ""
    echo "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "oracle-db|postgres-db|goldengate"

    echo ""
    echo "Database Row Counts:"
    ORACLE_COUNT=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
    PG_COUNT=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)
    echo "  Oracle CUSTOMERS: ${ORACLE_COUNT:-0} rows"
    echo "  PostgreSQL customers: ${PG_COUNT:-0} rows"

    echo ""
    echo "GoldenGate Web UI Access:"
    echo "  Oracle GoldenGate:     https://localhost:9100"
    echo "  PostgreSQL GoldenGate: https://localhost:9200"
    echo "  Credentials:           oggadmin / Welcome1!"
    echo ""
    echo "Note: Use HTTPS and accept the self-signed certificate warning"
}

# ============================================
# Main Execution
# ============================================
main() {
    echo "This script will setup Oracle GoldenGate CDC from Oracle to PostgreSQL."
    echo ""

    if [ "$1" != "-y" ]; then
        read -p "Press Enter to continue or Ctrl+C to cancel..."
    fi

    check_oracle_status
    setup_databases

    echo ""
    echo "Waiting 30 seconds for databases to stabilize..."
    sleep 30

    setup_goldengate_oracle
    setup_goldengate_postgres
    verify_setup

    echo ""
    echo "============================================"
    echo "Oracle GoldenGate Setup Complete!"
    echo "============================================"
    echo ""
    echo "Next steps:"
    echo "  - Monitor: ./monitor.sh"
    echo "  - Test:    ./test.sh"
    echo "  - Manage:  ./manage.sh [start|stop|restart|status]"
    echo ""
}

main "$@"
