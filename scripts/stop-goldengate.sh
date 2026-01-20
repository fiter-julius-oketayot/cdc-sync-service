#!/bin/bash

# Oracle GoldenGate Stop Script
# This script stops all GoldenGate processes gracefully

echo "============================================"
echo "Stopping Oracle GoldenGate Processes"
echo "============================================"
echo ""

echo "Step 1: Stopping Replicat on PostgreSQL..."
docker exec ogg-postgres-replicat bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
STOP REPLICAT rep_postgres
INFO ALL
EXIT
EOF"

echo "✓ Replicat stopped"
echo ""

echo "Step 2: Stopping Extract and Pump on Oracle..."
docker exec ogg-oracle-extract bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
STOP EXTRACT pump_oracle
STOP EXTRACT ext_oracle
INFO ALL
EXIT
EOF"

echo "✓ Extract and Pump stopped"
echo ""

echo "Step 3: Stopping Managers..."
docker exec ogg-oracle-extract bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
STOP MGR
EXIT
EOF"

docker exec ogg-postgres-replicat bash -c "cd /opt/oracle/ogg && ./ggsci << EOF
STOP MGR
EXIT
EOF"

echo "✓ Managers stopped"
echo ""

echo "============================================"
echo "Oracle GoldenGate Stopped Successfully!"
echo "============================================"
echo ""
echo "To restart: ./start-goldengate.sh"
echo ""

