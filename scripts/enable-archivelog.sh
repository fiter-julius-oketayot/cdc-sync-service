#!/bin/bash
# =====================================================
# Enable Oracle ARCHIVELOG Mode
# =====================================================
# This script enables ARCHIVELOG mode in Oracle XE
# Required for Debezium CDC to work

echo "=================================================="
echo "Enabling Oracle ARCHIVELOG Mode"
echo "=================================================="

# Step 1: Set recovery parameters
echo ""
echo "Step 1: Setting recovery file destination..."
docker exec oracle-db sqlplus -S / as sysdba <<EOF
ALTER SYSTEM SET db_recovery_file_dest_size = 10G SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest = '/opt/oracle/oradata' SCOPE=BOTH;
EXIT;
EOF

# Step 2: Shutdown database
echo ""
echo "Step 2: Shutting down database..."
docker exec oracle-db sqlplus -S / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
EXIT;
EOF

# Step 3: Startup in mount mode and enable archivelog
echo ""
echo "Step 3: Starting in MOUNT mode and enabling ARCHIVELOG..."
docker exec oracle-db sqlplus -S / as sysdba <<EOF
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
SELECT LOG_MODE FROM V\$DATABASE;
EXIT;
EOF

# Step 4: Verify
echo ""
echo "=================================================="
echo "Verification"
echo "=================================================="
docker exec oracle-db sqlplus -S / as sysdba <<EOF
SELECT LOG_MODE FROM V$DATABASE;
EXIT;
EOF

echo ""
echo "Done! If LOG_MODE shows 'ARCHIVELOG', you can now register the Oracle connector."
echo ""
echo "Next steps:"
echo "  cd scripts"
echo "  ./delete-connectors.sh"
echo "  ./register-connectors.sh"
echo "  ./check-connector-status.sh"

