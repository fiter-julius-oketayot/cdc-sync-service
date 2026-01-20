#!/bin/bash

# Verification script for updated container names
# This script verifies that all setup scripts can find the correct containers

set -e

echo "============================================"
echo "Container Name Update Verification"
echo "============================================"
echo ""

echo "Checking if Docker is available..."
if ! command -v docker &> /dev/null; then
    echo "✗ Docker is not available or not running"
    echo "Please start Docker Desktop and try again"
    exit 1
else
    echo "✓ Docker is available"
fi

echo ""
echo "Checking container detection logic..."
echo "------------------------------------"

# Test the same logic used in setup scripts
containers=("oracle-db" "postgres-db" "goldengate-oracle" "goldengate-postgres")

all_running=true
for container in "${containers[@]}"; do
    if docker ps | grep -q "$container"; then
        echo "✓ $container container is running"
    else
        echo "✗ $container container not found"
        all_running=false
    fi
done

echo ""
if [ "$all_running" = true ]; then
    echo "✓ All containers are running - setup scripts should work correctly"
    echo ""
    echo "You can now run:"
    echo "  ./setup-all.sh"
else
    echo "ℹ Some containers are not running yet"
    echo ""
    echo "To start all containers:"
    echo "  cd .."
    echo "  docker-compose up -d"
    echo "  cd scripts"
    echo "  ./setup-all.sh"
fi

echo ""
echo "============================================"
echo "Verification Complete"
echo "============================================"
