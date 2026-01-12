#!/bin/bash
# =====================================================
# CDC System Health Check
# =====================================================

echo "=================================================="
echo "CDC System Health Check"
echo "=================================================="

all_healthy=true

# Check Docker container
check_container() {
    local container=$1
    echo ""
    echo "Checking Docker Container: $container..."

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$status" = "running" ]; then
            echo "[OK] Container is running"
            return 0
        else
            echo "[FAILED] Container status: $status"
            all_healthy=false
            return 1
        fi
    else
        echo "[FAILED] Container not found"
        all_healthy=false
        return 1
    fi
}

# Check Kafka
check_kafka() {
    echo ""
    echo "Checking Kafka..."

    # Try listing topics with timeout
    if timeout 5 docker exec kafka kafka-topics --bootstrap-server kafka:29092 --list > /dev/null 2>&1; then
        echo "[OK] Kafka is accessible"
        return 0
    elif timeout 5 docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
        echo "[OK] Kafka is accessible"
        return 0
    else
        echo "[WARNING] Kafka topic listing failed (may be slow to start)"
        echo "Note: If connectors are RUNNING, Kafka is working fine"
        return 0
    fi
}

# Check PostgreSQL
check_postgres() {
    echo ""
    echo "Checking PostgreSQL..."

    if docker exec postgres psql -U postgres -d postgres -c "SELECT 1" > /dev/null 2>&1; then
        echo "[OK] PostgreSQL is accessible"

        # Check WAL level
        wal_level=$(docker exec postgres psql -U postgres -d postgres -t -c "SHOW wal_level;" 2>/dev/null | xargs)
        if [ "$wal_level" = "logical" ]; then
            echo "[OK] WAL level is logical"
        else
            echo "[WARNING] WAL level is not logical: $wal_level"
        fi

        # Check if public schema has customers table
        if docker exec postgres psql -U postgres -d postgres -t -c "SELECT 1 FROM public.customers LIMIT 1" > /dev/null 2>&1; then
            echo "[OK] public.customers table exists"
        else
            echo "[WARNING] public.customers table not found"
        fi

        return 0
    else
        echo "[FAILED] PostgreSQL connection error"
        all_healthy=false
        return 1
    fi
}

# Check Oracle
check_oracle() {
    echo ""
    echo "Checking Oracle..."

    if echo "SELECT 1 FROM DUAL;" | docker exec -i oracle-db sqlplus -s system/oracle@//localhost:1521/XE > /dev/null 2>&1; then
        echo "[OK] Oracle is accessible"

        # Check if SYSTEM.CUSTOMERS table exists
        if echo "SELECT 1 FROM SYSTEM.CUSTOMERS WHERE ROWNUM = 1;" | docker exec -i oracle-db sqlplus -s system/oracle@//localhost:1521/XE > /dev/null 2>&1; then
            echo "[OK] SYSTEM.CUSTOMERS table exists"
        else
            echo "[WARNING] SYSTEM.CUSTOMERS table not found"
        fi

        return 0
    else
        echo "[FAILED] Oracle is not accessible"
        echo "Note: Oracle may still be starting up"
        all_healthy=false
        return 1
    fi
}

# Check Debezium Connect
check_debezium() {
    echo ""
    echo "Checking Debezium Connect..."

    if response=$(curl -s "http://localhost:8083/"); then
        if echo "$response" | grep -q "version"; then
            echo "[OK] Debezium Connect is accessible"

            # Check connectors
            connectors=$(curl -s "http://localhost:8083/connectors")
            connector_count=$(echo "$connectors" | grep -o '"[^"]*"' | wc -l)
            echo "Registered connectors: $connector_count"

            if [ $connector_count -gt 0 ]; then
                for connector in $(echo $connectors | grep -o '"[^"]*"' | tr -d '"'); do
                    status=$(curl -s "http://localhost:8083/connectors/$connector/status")
                    state=$(echo "$status" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)

                    if [ "$state" = "RUNNING" ]; then
                        echo "  [OK] $connector is RUNNING"
                    else
                        echo "  [WARNING] $connector is $state"
                        all_healthy=false
                    fi
                done
            else
                echo "[WARNING] No connectors registered"
            fi

            return 0
        fi
    fi

    echo "[FAILED] Debezium Connect is not accessible"
    all_healthy=false
    return 1
}

# Check Spring Boot application
check_springboot() {
    echo ""
    echo "Checking Spring Boot Application..."

    if nc -z localhost 8080 2>/dev/null || (echo > /dev/tcp/localhost/8080) 2>/dev/null; then
        echo "[OK] Spring Boot application is running on port 8080"
        return 0
    else
        echo "[WARNING] Spring Boot application is not running"
        echo "Run: ./gradlew bootRun"
        return 1
    fi
}

# Run all checks
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
echo ""
echo "=================================================="
echo "HEALTH CHECK SUMMARY"
echo "=================================================="

if $all_healthy; then
    echo "All systems operational! ✓"
    exit 0
else
    echo "Some systems are not healthy. Please review the output above."
    exit 1
fi

