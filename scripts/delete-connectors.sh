#!/bin/bash
# =====================================================
# Delete Debezium Connectors
# =====================================================

CONNECT_URL="http://localhost:8083"

echo "=================================================="
echo "Delete Debezium Connectors"
echo "=================================================="

# Check if Debezium Connect is accessible
if ! curl -s "$CONNECT_URL" > /dev/null 2>&1; then
    echo ""
    echo "ERROR: Cannot connect to Debezium Connect"
    echo "Make sure Docker containers are running"
    exit 1
fi

# Get list of connectors
connectors=$(curl -s "$CONNECT_URL/connectors")

if [ "$connectors" = "[]" ]; then
    echo ""
    echo "No connectors to delete."
    exit 0
fi

echo ""
echo "Found connectors: $(echo $connectors | grep -o '"[^"]*"' | tr -d '"' | paste -sd,)"

# Delete each connector
for connector in $(echo $connectors | grep -o '"[^"]*"' | tr -d '"'); do
    echo ""
    echo "Deleting connector: $connector..."

    response=$(curl -s -w "\n%{http_code}" -X DELETE "$CONNECT_URL/connectors/$connector")
    http_code=$(echo "$response" | tail -1)

    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        echo "SUCCESS: Connector '$connector' deleted"
    elif [ "$http_code" = "404" ]; then
        echo "Connector '$connector' not found (already deleted)"
    else
        echo "ERROR: Failed to delete connector '$connector'"
    fi
done

# Verify deletion
echo ""
echo "Verifying deletion..."
sleep 2

remaining=$(curl -s "$CONNECT_URL/connectors")
if [ "$remaining" = "[]" ]; then
    echo "All connectors deleted successfully!"
else
    echo "Warning: Some connectors still exist: $remaining"
fi

echo ""
echo "Done!"

