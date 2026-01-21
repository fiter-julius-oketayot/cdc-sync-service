#!/bin/bash
# =====================================================
# Debezium Connector Management Script
# =====================================================
# Unified script for managing Debezium connectors
#
# Usage:
#   ./connectors.sh register   - Register all connectors
#   ./connectors.sh delete     - Delete all connectors
#   ./connectors.sh status     - Check connector status
#   ./connectors.sh restart    - Restart all connectors
# =====================================================

CONNECT_URL="http://localhost:8083"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTOR_DIR="$SCRIPT_DIR/../connectors"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if Debezium Connect is accessible
check_connect() {
    if ! curl -s "$CONNECT_URL" > /dev/null 2>&1; then
        print_error "Cannot connect to Debezium Connect at $CONNECT_URL"
        echo "Make sure Docker containers are running: docker-compose up -d"
        exit 1
    fi
}

# Wait for Debezium Connect to be ready
wait_for_connect() {
    echo -n "Waiting for Debezium Connect to be ready..."
    for i in {1..30}; do
        if curl -s "$CONNECT_URL" > /dev/null 2>&1; then
            echo " Ready!"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    print_error "Debezium Connect failed to start within 60 seconds"
    exit 1
}

# Register a single connector
register_connector() {
    local config_file=$1
    local connector_name=$2
    local config_path="$CONNECTOR_DIR/$config_file"

    echo ""
    echo "Registering $connector_name..."

    if [ ! -f "$config_path" ]; then
        print_error "Config file not found: $config_path"
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
        print_success "Connector '$connector_name' registered"
        return 0
    else
        print_error "Failed to register connector '$connector_name'"
        echo "Response: $response"
        return 1
    fi
}

# Register all connectors
cmd_register() {
    print_header "Registering Debezium Connectors"
    wait_for_connect

    oracle_ok=0
    postgres_ok=0

    register_connector "oracle-connector.json" "oracle-connector" && oracle_ok=1
    sleep 3
    register_connector "postgres-connector.json" "postgres-connector" && postgres_ok=1

    print_header "Registration Summary"
    [ $oracle_ok -eq 1 ] && print_success "Oracle Connector" || print_error "Oracle Connector"
    [ $postgres_ok -eq 1 ] && print_success "PostgreSQL Connector" || print_error "PostgreSQL Connector"

    echo ""
    echo "To check status: ./connectors.sh status"
}

# Delete all connectors
cmd_delete() {
    print_header "Deleting Debezium Connectors"
    check_connect

    connectors=$(curl -s "$CONNECT_URL/connectors")

    if [ "$connectors" = "[]" ]; then
        echo "No connectors to delete."
        return 0
    fi

    echo "Found connectors: $(echo $connectors | grep -o '"[^"]*"' | tr -d '"' | paste -sd,)"

    for connector in $(echo $connectors | grep -o '"[^"]*"' | tr -d '"'); do
        echo ""
        echo "Deleting connector: $connector..."

        response=$(curl -s -w "\n%{http_code}" -X DELETE "$CONNECT_URL/connectors/$connector")
        http_code=$(echo "$response" | tail -1)

        if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
            print_success "Connector '$connector' deleted"
        elif [ "$http_code" = "404" ]; then
            echo "Connector '$connector' not found (already deleted)"
        else
            print_error "Failed to delete connector '$connector'"
        fi
    done

    sleep 2
    remaining=$(curl -s "$CONNECT_URL/connectors")
    if [ "$remaining" = "[]" ]; then
        echo ""
        print_success "All connectors deleted successfully!"
    fi
}

# Check connector status
cmd_status() {
    print_header "Debezium Connector Status"
    check_connect

    connectors=$(curl -s "$CONNECT_URL/connectors")

    if [ "$connectors" = "[]" ]; then
        echo "No connectors registered."
        echo "To register: ./connectors.sh register"
        return 0
    fi

    echo "Registered connectors: $(echo $connectors | grep -o '"[^"]*"' | tr -d '"' | paste -sd,)"

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
            print_success "Connector State: $connector_state"
        else
            print_error "Connector State: $connector_state"
        fi
        echo "Worker ID: $worker_id"

        # Check tasks
        echo ""
        echo "Tasks:"
        task_state=$(echo "$status" | grep -o '"state":"[^"]*"' | tail -1 | cut -d'"' -f4)
        task_id=$(echo "$status" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

        if [ "$task_state" = "RUNNING" ]; then
            print_success "  Task $task_id: $task_state"
        else
            print_error "  Task $task_id: $task_state"
        fi

        # Show error trace if exists
        if echo "$status" | grep -q '"trace"'; then
            print_warning "  Error trace found - check Debezium logs: docker logs debezium-connect"
        fi
    done
}

# Restart connectors (delete + register)
cmd_restart() {
    print_header "Restarting Debezium Connectors"
    cmd_delete
    sleep 3
    cmd_register
}

# Main
case "${1:-status}" in
    register|reg|r)
        cmd_register
        ;;
    delete|del|d)
        cmd_delete
        ;;
    status|stat|s)
        cmd_status
        ;;
    restart|rest)
        cmd_restart
        ;;
    *)
        echo "Usage: $0 {register|delete|status|restart}"
        echo ""
        echo "Commands:"
        echo "  register (r)  - Register Oracle and PostgreSQL connectors"
        echo "  delete (d)    - Delete all connectors"
        echo "  status (s)    - Check connector status (default)"
        echo "  restart       - Delete and re-register all connectors"
        exit 1
        ;;
esac
