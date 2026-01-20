#!/bin/bash

# Force GoldenGate Web UI Initialization - Bash Version
# This script manually starts the web interface services in the containers

echo "============================================"
echo "Force Starting GoldenGate Web UI Services"
echo "============================================"
echo ""

# Step 1: Check and start containers
echo "Step 1: Checking container status..."
cd "$(dirname "$0")/.." || exit 1

oracle_running=$(docker ps --filter "name=goldengate-oracle" --format "{{.Names}}" 2>/dev/null)
postgres_running=$(docker ps --filter "name=goldengate-postgres" --format "{{.Names}}" 2>/dev/null)

if [ -z "$oracle_running" ]; then
    echo "Starting Oracle GoldenGate container..."
    docker-compose up -d goldengate-oracle
    sleep 30
fi

if [ -z "$postgres_running" ]; then
    echo "Starting PostgreSQL GoldenGate container..."
    docker-compose up -d goldengate-postgres
    sleep 30
fi

echo "✓ Containers are running"

# Step 2: Recreate containers with correct configuration
echo ""
echo "Step 2: Recreating containers with correct port mappings..."
echo "Stopping containers..."
docker-compose down goldengate-oracle goldengate-postgres 2>/dev/null

echo "Starting with corrected configuration..."
docker-compose up -d goldengate-oracle goldengate-postgres

echo "Waiting 90 seconds for full initialization..."
for i in {1..90}; do
    echo -ne "Initializing... $i/90 seconds\r"
    sleep 1
done
echo ""

# Step 3: Initialize Oracle GoldenGate web services
echo ""
echo "Step 3: Initializing Oracle GoldenGate web services..."

# Create directories
docker exec goldengate-oracle bash -c 'mkdir -p /u02/deployments/Local/etc/conf /opt/oracle/ogg/dirdat /opt/oracle/ogg/dirprm' 2>/dev/null

# Start ServiceManager in background
docker exec goldengate-oracle bash -c 'cd /u01/ogg; nohup /u01/ogg/bin/ServiceManager >/tmp/servicemanager.log 2>&1 &' 2>/dev/null
sleep 30

echo "✓ Oracle GoldenGate services initialized"

# Step 4: Initialize PostgreSQL GoldenGate web services
echo ""
echo "Step 4: Initializing PostgreSQL GoldenGate web services..."

# Create directories
docker exec goldengate-postgres bash -c 'mkdir -p /u02/deployments/Local/etc/conf /opt/oracle/ogg/dirdat /opt/oracle/ogg/dirprm' 2>/dev/null

# Start ServiceManager in background
docker exec goldengate-postgres bash -c 'cd /u01/ogg; nohup /u01/ogg/bin/ServiceManager >/tmp/servicemanager.log 2>&1 &' 2>/dev/null
sleep 30

echo "✓ PostgreSQL GoldenGate services initialized"

# Step 5: Test web UI accessibility
echo ""
echo "Step 5: Testing web UI accessibility..."
echo "Waiting additional 30 seconds for services to stabilize..."
sleep 30

echo ""
echo "Testing Oracle GoldenGate Web UI (localhost:9100):"
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://localhost:9100 | grep -q "200\|302\|401"; then
    echo "✓ Oracle GoldenGate Web UI is accessible at http://localhost:9100"
    oracle_working=true
else
    echo "⚠ Oracle GoldenGate Web UI is not accessible yet"
    oracle_working=false
fi

echo ""
echo "Testing PostgreSQL GoldenGate Web UI (localhost:9200):"
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://localhost:9200 | grep -q "200\|302\|401"; then
    echo "✓ PostgreSQL GoldenGate Web UI is accessible at http://localhost:9200"
    postgres_working=true
else
    echo "⚠ PostgreSQL GoldenGate Web UI is not accessible yet"
    postgres_working=false
fi

# Step 6: Show port mappings
echo ""
echo "Step 6: Verifying port mappings..."
echo "Oracle GoldenGate ports:"
oracle_ports=$(docker port goldengate-oracle 2>/dev/null)
if [ -n "$oracle_ports" ]; then
    echo "$oracle_ports" | sed 's/^/  /'
else
    echo "  No ports mapped"
fi

echo ""
echo "PostgreSQL GoldenGate ports:"
postgres_ports=$(docker port goldengate-postgres 2>/dev/null)
if [ -n "$postgres_ports" ]; then
    echo "$postgres_ports" | sed 's/^/  /'
else
    echo "  No ports mapped"
fi

# Step 7: Show container processes
echo ""
echo "Step 7: Container process verification..."
echo "Oracle GoldenGate processes:"
oracle_processes=$(docker exec goldengate-oracle ps aux 2>/dev/null | grep -E "ServiceManager|adminsrvr|nginx" | grep -v grep)
if [ -n "$oracle_processes" ]; then
    echo "$oracle_processes" | sed 's/^/  /'
else
    echo "  No web services found running"
fi

echo ""
echo "PostgreSQL GoldenGate processes:"
postgres_processes=$(docker exec goldengate-postgres ps aux 2>/dev/null | grep -E "ServiceManager|adminsrvr|nginx" | grep -v grep)
if [ -n "$postgres_processes" ]; then
    echo "$postgres_processes" | sed 's/^/  /'
else
    echo "  No web services found running"
fi

# Step 8: Results and next steps
echo ""
echo "============================================"
echo "Setup Results"
echo "============================================"

if [ "$oracle_working" = true ] && [ "$postgres_working" = true ]; then
    echo ""
    echo "🎉 SUCCESS: Both Web UIs are now accessible!"
elif [ "$oracle_working" = true ] || [ "$postgres_working" = true ]; then
    echo ""
    echo "⚠️  PARTIAL SUCCESS: Some Web UIs are accessible"
else
    echo ""
    echo "❌ ISSUE: Web UIs are still not accessible"
fi

echo ""
echo "🌐 Web UI Access Information:"
echo "Oracle GoldenGate:     http://localhost:9100"
echo "PostgreSQL GoldenGate: http://localhost:9200"
echo "Username: oggadmin"
echo "Password: Welcome1"

if [ "$oracle_working" != true ] || [ "$postgres_working" != true ]; then
    echo ""
    echo "🔧 Additional Troubleshooting:"
    echo "1. Wait 5-10 more minutes for services to fully start"
    echo "2. Check container logs:"
    echo "   docker logs goldengate-oracle --tail=20"
    echo "   docker logs goldengate-postgres --tail=20"
    echo "3. Try accessing via container IP:"
    echo "   docker inspect goldengate-oracle | grep IPAddress"
    echo "4. Restart Docker and try again"
    echo "5. Use alternative dashboard: ./create-dashboard.sh"
fi

echo ""
echo "============================================"
echo ""
