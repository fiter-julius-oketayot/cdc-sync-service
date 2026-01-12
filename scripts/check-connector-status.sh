#!/bin/bash
# =====================================================
# Check Debezium Connector Status
# =====================================================

CONNECT_URL="http://localhost:8083"

echo "=================================================="
echo "Debezium Connector Status"
echo "=================================================="

# Check if Debezium Connect is accessible
if ! curl -s "$CONNECT_URL" > /dev/null 2>&1; then
    echo ""
    echo "ERROR: Cannot connect to Debezium Connect at $CONNECT_URL"
    echo "Make sure Docker containers are running"
    exit 1
fi

# Get list of connectors
connectors=$(curl -s "$CONNECT_URL/connectors")

if [ "$connectors" = "[]" ]; then
    echo ""
    echo "No connectors registered yet."
    exit 0
fi

echo ""
echo "Connectors: $(echo $connectors | grep -o '"[^"]*"' | tr -d '"' | paste -sd,)"

# Check status of each connector
for connector in $(echo $connectors | grep -o '"[^"]*"' | tr -d '"'); do
    echo ""
    echo "--------------------------------------------------"
    echo "Connector: $connector"
    echo "--------------------------------------------------"

    status=$(curl -s "$CONNECT_URL/connectors/$connector/status")

    # Parse connector state
    connector_state=$(echo "$status" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
    worker_id=$(echo "$status" | grep -o '"worker_id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ "$connector_state" = "RUNNING" ]; then
        echo "Connector State: $connector_state ✓"
    else
        echo "Connector State: $connector_state ✗"
    fi
    echo "Worker ID: $worker_id"

    # Check tasks
    echo ""
    echo "Tasks:"
    task_count=$(echo "$status" | grep -o '"tasks":\[' | wc -l)

    if [ $task_count -gt 0 ]; then
        task_state=$(echo "$status" | grep -o '"state":"[^"]*"' | tail -1 | cut -d'"' -f4)
        task_id=$(echo "$status" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

        if [ "$task_state" = "RUNNING" ]; then
            echo "  Task $task_id: $task_state ✓"
        else
            echo "  Task $task_id: $task_state ✗"
        fi

        # Show error if exists
        if echo "$status" | grep -q '"trace"'; then
            echo "  Error found in trace (check Debezium Connect logs)"
        fi
    fi
done

echo ""
echo "=================================================="
echo "End of Status Report"
echo "=================================================="

