#!/bin/bash

# Oracle GoldenGate Monitoring Script
# This script monitors and performs health checks on the GoldenGate setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

print_header() {
    echo ""
    echo "============================================"
    echo "$1"
    echo "============================================"
}

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASS++))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAIL++))
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((WARN++))
}

# ============================================
# Container Status
# ============================================
check_containers() {
    print_header "Container Status"

    for container in oracle-db postgres-db goldengate-oracle goldengate-postgres; do
        if docker ps | grep -q "$container"; then
            STATUS=$(docker ps --filter "name=$container" --format "{{.Status}}")
            check_pass "$container: $STATUS"
        else
            check_fail "$container: Not running"
        fi
    done
}

# ============================================
# Database Connectivity
# ============================================
check_databases() {
    print_header "Database Connectivity"

    # Oracle
    if docker exec oracle-db bash -c "echo 'SELECT 1 FROM DUAL; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" >/dev/null 2>&1; then
        check_pass "Oracle database is accessible"

        # Check ARCHIVELOG mode
        ARCHIVELOG=$(docker exec oracle-db bash -c "echo 'SELECT LOG_MODE FROM V\$DATABASE; EXIT;' | sqlplus -S / as sysdba" 2>/dev/null | grep -E 'ARCHIVELOG|NOARCHIVELOG' | head -1)
        if echo "$ARCHIVELOG" | grep -q "ARCHIVELOG"; then
            check_pass "Oracle ARCHIVELOG mode: enabled"
        else
            check_warn "Oracle ARCHIVELOG mode: disabled (may limit CDC functionality)"
        fi

        # Check supplemental logging
        SUPP_LOG=$(docker exec oracle-db bash -c "echo 'SELECT SUPPLEMENTAL_LOG_DATA_MIN FROM V\$DATABASE; EXIT;' | sqlplus -S / as sysdba" 2>/dev/null | grep -E 'YES|NO' | head -1)
        if echo "$SUPP_LOG" | grep -q "YES"; then
            check_pass "Oracle supplemental logging: enabled"
        else
            check_warn "Oracle supplemental logging: disabled"
        fi
    else
        check_fail "Oracle database is NOT accessible"
    fi

    # PostgreSQL
    if docker exec postgres-db psql -U postgres -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        check_pass "PostgreSQL database is accessible"
    else
        check_fail "PostgreSQL database is NOT accessible"
    fi
}

# ============================================
# GoldenGate Services
# ============================================
check_goldengate_services() {
    print_header "GoldenGate Services"

    echo "Oracle GoldenGate Container:"
    OGG_ORACLE_SERVICES=$(docker exec goldengate-oracle bash -c "ps aux | grep -E 'ServiceManager|adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")
    if [ "$OGG_ORACLE_SERVICES" -gt "0" ]; then
        check_pass "Oracle GoldenGate: $OGG_ORACLE_SERVICES service(s) running"
        docker exec goldengate-oracle bash -c "ps aux | grep -E 'ServiceManager|adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | awk '{print \"    - \" \$11}'" 2>/dev/null || true
    else
        check_fail "Oracle GoldenGate: No services running"
    fi

    echo ""
    echo "PostgreSQL GoldenGate Container:"
    OGG_PG_SERVICES=$(docker exec goldengate-postgres bash -c "ps aux | grep -E 'ServiceManager|adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | wc -l" 2>/dev/null || echo "0")
    if [ "$OGG_PG_SERVICES" -gt "0" ]; then
        check_pass "PostgreSQL GoldenGate: $OGG_PG_SERVICES service(s) running"
        docker exec goldengate-postgres bash -c "ps aux | grep -E 'ServiceManager|adminsrvr|distsrvr|recvsrvr|pmsrvr' | grep -v grep | awk '{print \"    - \" \$11}'" 2>/dev/null || true
    else
        check_fail "PostgreSQL GoldenGate: No services running"
    fi
}

# ============================================
# Data Synchronization Status
# ============================================
check_data_sync() {
    print_header "Data Synchronization Status"

    ORACLE_COUNT=$(docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
    PG_COUNT=$(docker exec postgres-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM public.customers;" 2>/dev/null)

    echo "  Row Counts:"
    echo "    Oracle CUSTOMERS:     ${ORACLE_COUNT:-Error}"
    echo "    PostgreSQL customers: ${PG_COUNT:-Error}"

    if [ "${ORACLE_COUNT:-0}" = "${PG_COUNT:-0}" ] && [ "${ORACLE_COUNT:-0}" != "0" ]; then
        check_pass "Row counts match!"
    elif [ "${ORACLE_COUNT:-0}" = "0" ] && [ "${PG_COUNT:-0}" = "0" ]; then
        check_warn "Both tables are empty"
    else
        check_warn "Row counts differ (CDC may not be configured yet)"
    fi
}

# ============================================
# Web UI Access
# ============================================
check_web_ui() {
    print_header "Web UI Access"

    echo "  Oracle GoldenGate:     https://localhost:9100"
    echo "  PostgreSQL GoldenGate: https://localhost:9200"
    echo "  Credentials:           oggadmin / Welcome1!"
    echo ""
    echo "  Note: Accept the self-signed certificate warning in your browser"
}

# ============================================
# Recent Logs
# ============================================
show_logs() {
    print_header "Recent Container Logs"

    echo "Oracle GoldenGate (last 5 lines):"
    docker logs goldengate-oracle --tail=5 2>&1 | grep -E "(ERROR|WARN|INFO|started|running)" | tail -5 || echo "  No relevant entries"

    echo ""
    echo "PostgreSQL GoldenGate (last 5 lines):"
    docker logs goldengate-postgres --tail=5 2>&1 | grep -E "(ERROR|WARN|INFO|started|running)" | tail -5 || echo "  No relevant entries"
}

# ============================================
# Summary
# ============================================
print_summary() {
    print_header "Health Check Summary"

    echo -e "  ${GREEN}Passed:${NC}   $PASS"
    echo -e "  ${YELLOW}Warnings:${NC} $WARN"
    echo -e "  ${RED}Failed:${NC}   $FAIL"
    echo ""

    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}Overall Status: HEALTHY${NC}"
    elif [ $FAIL -lt 3 ]; then
        echo -e "${YELLOW}Overall Status: DEGRADED${NC}"
    else
        echo -e "${RED}Overall Status: UNHEALTHY${NC}"
    fi
}

# ============================================
# Main
# ============================================
main() {
    echo "============================================"
    echo "Oracle GoldenGate Health Monitor"
    echo "============================================"

    check_containers
    check_databases
    check_goldengate_services
    check_data_sync
    check_web_ui
    show_logs
    print_summary

    echo ""
}

main "$@"
