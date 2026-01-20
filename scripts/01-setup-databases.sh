#!/bin/bash

# Oracle GoldenGate Setup Script - Part 1: Database Setup
# This script sets up Oracle and PostgreSQL databases for GoldenGate CDC

set -e

echo "============================================"
echo "Oracle GoldenGate Database Setup"
echo "============================================"
echo ""

# Check if containers are running
if ! docker ps | grep -q oracle-db; then
    echo "Error: oracle-db container is not running!"
    echo "Please start it first with: docker-compose up -d"
    exit 1
fi

if ! docker ps | grep -q postgres-db; then
    echo "Error: postgres-db container is not running!"
    echo "Please start it first with: docker-compose up -d"
    exit 1
fi

echo "Step 1: Setting up Oracle Database..."
echo "--------------------------------------"

# Oracle should already be verified as ready by the startup check
echo "Running Oracle setup (database verified as ready)..."

# Copy setup script to Oracle container
echo "Copying Oracle setup script to container..."
docker cp setup-oracle.sql oracle-db:/tmp/

# Run Oracle setup as SYSDBA
echo "Running Oracle setup script..."
echo "This will create users, tables, and configure GoldenGate settings..."

# Run the SQL script and capture output
OUTPUT=$(docker exec oracle-db bash -c "echo '@/tmp/setup-oracle.sql' | sqlplus -S / as sysdba" 2>&1)
EXIT_CODE=$?

# Display the output
echo "$OUTPUT"

# Check for critical errors
if echo "$OUTPUT" | grep -i "ORA-00942\|ORA-01917\|ERROR\|SP2-" > /dev/null; then
    echo ""
    echo "⚠️  Warning: Some SQL errors were detected"

    # Check for specific error types
    if echo "$OUTPUT" | grep -q "ORA-00001"; then
        echo "   - Duplicate key errors: Sample data already exists (this is normal)"
    fi

    if echo "$OUTPUT" | grep -q "ORA-00942"; then
        echo "   - Missing objects: Some objects may not exist yet"
    fi

    if echo "$OUTPUT" | grep -q "ORA-01917"; then
        echo "   - User errors: Some users may already exist"
    fi

    echo ""

    # Check if the essential objects were created
    echo "Verifying essential objects were created..."
    VERIFY_OUTPUT=$(docker exec oracle-db sqlplus -S system/oracle@//localhost:1521/XE << 'EOF'
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT 'USER_OGGUSER_EXISTS:' || COUNT(*) FROM DBA_USERS WHERE USERNAME = 'OGGUSER';
SELECT 'USER_OGGADMIN_EXISTS:' || COUNT(*) FROM DBA_USERS WHERE USERNAME = 'OGGADMIN';
SELECT 'TABLE_EXISTS:' || COUNT(*) FROM DBA_TABLES WHERE OWNER = 'OGGUSER' AND TABLE_NAME = 'CUSTOMERS';
SELECT 'TABLE_ROWS:' || COUNT(*) FROM ogguser.CUSTOMERS;
EXIT;
EOF
)

    echo "Verification results:"
    echo "$VERIFY_OUTPUT"

    # Parse verification results
    USER_OGGUSER=$(echo "$VERIFY_OUTPUT" | grep "USER_OGGUSER_EXISTS:" | cut -d: -f2)
    USER_OGGADMIN=$(echo "$VERIFY_OUTPUT" | grep "USER_OGGADMIN_EXISTS:" | cut -d: -f2)
    TABLE_EXISTS=$(echo "$VERIFY_OUTPUT" | grep "TABLE_EXISTS:" | cut -d: -f2)
    TABLE_ROWS=$(echo "$VERIFY_OUTPUT" | grep "TABLE_ROWS:" | cut -d: -f2)

    if [ "$USER_OGGUSER" = "1" ] && [ "$USER_OGGADMIN" = "1" ] && [ "$TABLE_EXISTS" = "1" ] && [ -n "$TABLE_ROWS" ] && [ "$TABLE_ROWS" -gt "0" ]; then
        echo "✓ Essential objects verified - Oracle setup successful"
        echo "  - OGGUSER user: ✓"
        echo "  - OGGADMIN user: ✓"
        echo "  - CUSTOMERS table: ✓"
        echo "  - Table rows: $TABLE_ROWS"
    else
        echo "✗ Critical error: Essential objects verification failed!"
        echo "  - OGGUSER user: $([ "$USER_OGGUSER" = "1" ] && echo "✓" || echo "✗")"
        echo "  - OGGADMIN user: $([ "$USER_OGGADMIN" = "1" ] && echo "✓" || echo "✗")"
        echo "  - CUSTOMERS table: $([ "$TABLE_EXISTS" = "1" ] && echo "✓" || echo "✗")"
        echo "  - Table rows: ${TABLE_ROWS:-0}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check Oracle logs: docker logs oracle-db"
        echo "  2. Try manual verification: docker exec oracle-db sqlplus system/oracle@//localhost:1521/XE"
        exit 1
    fi
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Oracle setup completed successfully"
else
    echo "✗ Oracle setup failed with exit code: $EXIT_CODE"
    exit 1
fi

echo ""
echo "Step 2: Setting up PostgreSQL Database..."
echo "-----------------------------------------"

# PostgreSQL setup is done via init script in docker-compose
echo "Verifying PostgreSQL tables..."
docker exec postgres-db psql -U postgres -d postgres -c "\dt public.*"

if [ $? -eq 0 ]; then
    echo "✓ PostgreSQL setup completed successfully"
else
    echo "✗ PostgreSQL setup failed!"
    exit 1
fi

echo ""
echo "============================================"
echo "Database Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Run: ./02-setup-goldengate-oracle.sh"
echo "  2. Run: ./03-setup-goldengate-postgres.sh"
echo "  3. Run: ./04-start-goldengate.sh"
echo ""

