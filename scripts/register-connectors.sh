#!/bin/bash
# =====================================================
# Register Debezium Connectors
# =====================================================

CONNECT_URL="http://localhost:8083"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTOR_DIR="$SCRIPT_DIR/../connectors"

echo "=================================================="
echo "Registering Debezium Connectors"
echo "=================================================="

# Wait for Debezium Connect to be ready
echo -n "Waiting for Debezium Connect to be ready..."
for i in {1..30}; do
    if curl -s "$CONNECT_URL" > /dev/null 2>&1; then
        echo " Ready!"
        break
    fi
    echo -n "."
    sleep 2
done

if ! curl -s "$CONNECT_URL" > /dev/null 2>&1; then
    echo ""
    echo "ERROR: Debezium Connect failed to start"
    exit 1
fi

# Function to register a connector
register_connector() {
    local config_file=$1
    local connector_name=$2
    local config_path="$CONNECTOR_DIR/$config_file"

    echo ""
    echo "--------------------------------------------------"
    echo "Registering $connector_name..."
    echo "--------------------------------------------------"

    if [ ! -f "$config_path" ]; then
        echo "ERROR: Config file not found: $config_path"
        return 1
    fi

    # Delete if exists
    curl -s -X DELETE "$CONNECT_URL/connectors/$connector_name" > /dev/null 2>&1
    sleep 2

    # Register connector
    response=$(curl -s -X POST "$CONNECT_URL/connectors" \
        -H "Content-Type: application/json" \
        -d @"$config_path")

    if echo "$response" | grep -q "\"name\""; then
        echo "SUCCESS: Connector '$connector_name' registered!"
        return 0
    else
        echo "ERROR: Failed to register connector '$connector_name'"
        echo "$response"
        return 1
    fi
}

# Register connectors
oracle_success=0
postgres_success=0

register_connector "oracle-connector.json" "oracle-connector" && oracle_success=1
sleep 3
register_connector "postgres-connector.json" "postgres-connector" && postgres_success=1

# Summary
echo ""
echo "=================================================="
echo "REGISTRATION SUMMARY"
echo "=================================================="

[ $oracle_success -eq 1 ] && echo "[OK] Oracle Connector" || echo "[FAILED] Oracle Connector"
[ $postgres_success -eq 1 ] && echo "[OK] PostgreSQL Connector" || echo "[FAILED] PostgreSQL Connector"

# List all connectors
echo ""
echo "Registered connectors:"
curl -s "$CONNECT_URL/connectors" | grep -o '"[^"]*"' | tr -d '"' | paste -sd,

echo ""
echo "Done!"
echo "To check connector status, run: ./check-connector-status.sh"
