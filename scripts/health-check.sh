#!/bin/bash
# =====================================================
# CDC System Health Check
# =====================================================
# Comprehensive health check for all CDC components
#
# Usage: ./health-check.sh
# =====================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

all_healthy=true

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
    echo -e "${RED}[FAILED]${NC} $1"
    all_healthy=false
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check Docker container
check_container() {
    local container=$1
    echo ""
    echo "Checking container: $container..."

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$status" = "running" ]; then
            print_success "Container is running"
            return 0
        else
            print_error "Container status: $status"
            return 1
        fi
    else
        print_error "Container not found"
        return 1
    fi
}

# Check Kafka
check_kafka() {
    echo ""
    echo "Checking Kafka..."

    if timeout 5 docker exec kafka kafka-topics --bootstrap-server kafka:29092 --list > /dev/null 2>&1; then
        print_success "Kafka is accessible"

        # List CDC topics
        topics=$(docker exec kafka kafka-topics --bootstrap-server kafka:29092 --list 2>/dev/null | grep -E "^(oracle|postgres)\." || true)
        if [ -n "$topics" ]; then
            echo "  CDC Topics:"
            echo "$topics" | while read topic; do
                echo "    - $topic"
            done
        fi
        return 0
    else
        print_warning "Kafka topic listing failed (may be slow to start)"
        return 0
    fi
}

# Check PostgreSQL
check_postgres() {
    echo ""
    echo "Checking PostgreSQL..."

    if docker exec postgres psql -U postgres -d postgres -c "SELECT 1" > /dev/null 2>&1; then
        print_success "PostgreSQL is accessible"

        # Check WAL level
        wal_level=$(docker exec postgres psql -U postgres -d postgres -t -c "SHOW wal_level;" 2>/dev/null | xargs)
        if [ "$wal_level" = "logical" ]; then
            print_success "WAL level is logical"
        else
            print_warning "WAL level is '$wal_level' (expected 'logical')"
        fi

        # Check customers table
        if docker exec postgres psql -U postgres -d postgres -t -c "SELECT 1 FROM public.customers LIMIT 1" > /dev/null 2>&1; then
            count=$(docker exec postgres psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM public.customers" 2>/dev/null | xargs)
            print_success "public.customers table exists ($count rows)"
        else
            print_warning "public.customers table not found - run: ./setup-postgres.sh"
        fi

        return 0
    else
        print_error "PostgreSQL connection failed"
        return 1
    fi
}

# Check Oracle
check_oracle() {
    echo ""
    echo "Checking Oracle..."

    if echo "SELECT 1 FROM DUAL;" | docker exec -i oracle-db sqlplus -s / as sysdba > /dev/null 2>&1; then
        print_success "Oracle is accessible"

        # Check ARCHIVELOG mode
        log_mode=$(echo "SET HEADING OFF FEEDBACK OFF; SELECT LOG_MODE FROM V\$DATABASE;" | docker exec -i oracle-db sqlplus -s / as sysdba 2>/dev/null | xargs)
        if [ "$log_mode" = "ARCHIVELOG" ]; then
            print_success "ARCHIVELOG mode enabled"
        else
            print_warning "ARCHIVELOG mode is '$log_mode' - run: ./setup-oracle.sh"
        fi

        # Check DBZUSER.CUSTOMERS table
        if echo "SELECT 1 FROM DBZUSER.CUSTOMERS WHERE ROWNUM = 1;" | docker exec -i oracle-db sqlplus -s / as sysdba > /dev/null 2>&1; then
            count=$(echo "SET HEADING OFF FEEDBACK OFF; SELECT COUNT(*) FROM DBZUSER.CUSTOMERS;" | docker exec -i oracle-db sqlplus -s / as sysdba 2>/dev/null | xargs)
            print_success "DBZUSER.CUSTOMERS table exists ($count rows)"
        else
            print_warning "DBZUSER.CUSTOMERS table not found - run: ./setup-oracle.sh"
        fi

        return 0
    else
        print_error "Oracle connection failed"
        echo "  Note: Oracle may still be starting up (can take 2-3 minutes)"
        return 1
    fi
}

# Check Debezium Connect
check_debezium() {
    echo ""
    echo "Checking Debezium Connect..."

    if response=$(curl -s "http://localhost:8083/"); then
        if echo "$response" | grep -q "version"; then
            print_success "Debezium Connect is accessible"

            # Check connectors
            connectors=$(curl -s "http://localhost:8083/connectors")
            connector_count=$(echo "$connectors" | grep -o '"[^"]*"' | wc -l)

            if [ $connector_count -gt 0 ]; then
                echo "  Registered connectors: $connector_count"

                for connector in $(echo $connectors | grep -o '"[^"]*"' | tr -d '"'); do
                    status=$(curl -s "http://localhost:8083/connectors/$connector/status")
                    state=$(echo "$status" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)

                    if [ "$state" = "RUNNING" ]; then
                        print_success "  $connector: RUNNING"
                    else
                        print_error "  $connector: $state"
                    fi
                done
            else
                print_warning "No connectors registered - run: ./connectors.sh register"
            fi

            return 0
        fi
    fi

    print_error "Debezium Connect is not accessible"
    return 1
}

# Check Spring Boot application
check_springboot() {
    echo ""
    echo "Checking Spring Boot Application..."

    if nc -z localhost 8080 2>/dev/null || (echo > /dev/tcp/localhost/8080) 2>/dev/null; then
        print_success "Spring Boot application is running on port 8080"
        return 0
    else
        print_warning "Spring Boot application is not running"
        echo "  Run: ./gradlew bootRun"
        return 1
    fi
}

# Main
print_header "CDC System Health Check"

echo ""
echo "==================== INFRASTRUCTURE ===================="
check_container "kafka"
check_container "postgres"
check_container "oracle-db"
check_container "debezium-connect"

echo ""
echo "==================== SERVICES ===================="
check_kafka
check_postgres
check_oracle
check_debezium

echo ""
echo "==================== APPLICATION ===================="
check_springboot

# Summary
print_header "HEALTH CHECK SUMMARY"

if $all_healthy; then
    echo -e "${GREEN}All systems operational!${NC} ✓"
    echo ""
    echo "You can now test CDC:"
    echo "  1. Insert in Oracle:    docker exec oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE"
    echo "     INSERT INTO CUSTOMERS VALUES (999, 'Test', 'User', 'test@example.com'); COMMIT;"
    echo ""
    echo "  2. Verify in PostgreSQL: docker exec postgres psql -U postgres -c \"SELECT * FROM public.customers WHERE id = 999;\""
    exit 0
else
    echo -e "${RED}Some systems are not healthy.${NC}"
    echo "Please review the output above and fix any issues."
    exit 1
fi
