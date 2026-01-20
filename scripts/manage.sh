#!/bin/bash

# Oracle GoldenGate Management Script
# Usage: ./manage.sh [start|stop|restart|status|logs]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

COMMAND=${1:-status}

print_usage() {
    echo "Oracle GoldenGate Management Script"
    echo ""
    echo "Usage: ./manage.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  status    Show service status (default)"
    echo "  logs      Show recent logs"
    echo "  clean     Stop and remove all containers and volumes"
    echo ""
}

# ============================================
# Start Services
# ============================================
do_start() {
    echo "============================================"
    echo "Starting Oracle GoldenGate Services"
    echo "============================================"
    echo ""

    echo "Starting containers..."
    docker-compose up -d

    echo ""
    echo "Waiting for services to start..."
    sleep 10

    echo ""
    do_status
}

# ============================================
# Stop Services
# ============================================
do_stop() {
    echo "============================================"
    echo "Stopping Oracle GoldenGate Services"
    echo "============================================"
    echo ""

    docker-compose stop

    echo ""
    echo "✓ All services stopped"
    echo ""
    echo "To start again: ./manage.sh start"
}

# ============================================
# Restart Services
# ============================================
do_restart() {
    echo "============================================"
    echo "Restarting Oracle GoldenGate Services"
    echo "============================================"
    echo ""

    echo "Stopping services..."
    docker-compose stop

    echo ""
    echo "Starting services..."
    docker-compose up -d

    echo ""
    echo "Waiting for services to start..."
    sleep 15

    echo ""
    do_status
}

# ============================================
# Show Status
# ============================================
do_status() {
    echo "============================================"
    echo "Oracle GoldenGate Service Status"
    echo "============================================"
    echo ""

    echo "Container Status:"
    echo "-----------------"
    docker-compose ps 2>/dev/null || docker ps --filter "name=oracle-db" --filter "name=postgres-db" --filter "name=goldengate" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    echo "Database Row Counts:"
    echo "--------------------"
    ORACLE_COUNT=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
    PG_COUNT=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)
    echo "  Oracle CUSTOMERS:     ${ORACLE_COUNT:-N/A} rows"
    echo "  PostgreSQL customers: ${PG_COUNT:-N/A} rows"

    echo ""
    echo "GoldenGate Services:"
    echo "--------------------"
    OGG_ORACLE=$(docker exec goldengate-oracle bash -c "ps aux | grep -E 'ServiceManager|adminsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")
    OGG_PG=$(docker exec goldengate-postgres bash -c "ps aux | grep -E 'ServiceManager|adminsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")
    echo "  Oracle GoldenGate:     $OGG_ORACLE service(s)"
    echo "  PostgreSQL GoldenGate: $OGG_PG service(s)"

    echo ""
    echo "Web UI Access:"
    echo "--------------"
    echo "  Oracle GoldenGate:     https://localhost:9100"
    echo "  PostgreSQL GoldenGate: https://localhost:9200"
    echo "  Credentials:           oggadmin / Welcome1!"
    echo ""
}

# ============================================
# Show Logs
# ============================================
do_logs() {
    echo "============================================"
    echo "Oracle GoldenGate Logs"
    echo "============================================"
    echo ""

    echo "Oracle Database (last 20 lines):"
    echo "---------------------------------"
    docker logs oracle-db --tail=20 2>&1 | tail -20

    echo ""
    echo "PostgreSQL Database (last 20 lines):"
    echo "-------------------------------------"
    docker logs postgres-db --tail=20 2>&1 | tail -20

    echo ""
    echo "Oracle GoldenGate (last 20 lines):"
    echo "-----------------------------------"
    docker logs goldengate-oracle --tail=20 2>&1 | tail -20

    echo ""
    echo "PostgreSQL GoldenGate (last 20 lines):"
    echo "---------------------------------------"
    docker logs goldengate-postgres --tail=20 2>&1 | tail -20

    echo ""
    echo "For live logs, use:"
    echo "  docker logs -f goldengate-oracle"
    echo "  docker logs -f goldengate-postgres"
    echo ""
}

# ============================================
# Clean Everything
# ============================================
do_clean() {
    echo "============================================"
    echo "Cleaning Oracle GoldenGate Environment"
    echo "============================================"
    echo ""
    echo "⚠️  WARNING: This will delete ALL data!"
    echo ""
    read -p "Are you sure? (yes/no): " CONFIRM

    if [ "$CONFIRM" = "yes" ]; then
        echo ""
        echo "Stopping and removing containers..."
        docker-compose down -v

        echo ""
        echo "✓ All containers and volumes removed"
        echo ""
        echo "To start fresh: docker-compose up -d && ./scripts/setup.sh"
    else
        echo "Cancelled."
    fi
}

# ============================================
# Main
# ============================================
case "$COMMAND" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_restart
        ;;
    status)
        do_status
        ;;
    logs)
        do_logs
        ;;
    clean)
        do_clean
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo ""
        print_usage
        exit 1
        ;;
esac
