#!/bin/bash
set -e

echo "=========================================================="
echo " Starting PMS Services Gracefully (Low Memory Safe)      "
echo "=========================================================="

# Function to wait for a container to become healthy
wait_for_healthy() {
  local container=$1
  echo "Waiting for $container to become healthy..."
  until [ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}running{{end}}' "$container" 2>/dev/null)" = "healthy" ]; do
    printf "."
    sleep 2
  done
  echo " [OK] $container is healthy!"
}

# 1. Base Infrastructure
echo ""
echo ">>> Step 1/5: Starting Databases & Messaging (Postgres, Redis, Kafka)..."
docker compose up -d postgres redis kafka

wait_for_healthy postgres
wait_for_healthy kafka
sleep 2

# 2. Core Dependencies
echo ""
echo ">>> Step 2/5: Starting Core Services (Auth & Billing)..."
docker compose up -d auth-service billing-service
echo "Giving JVM services 12s to initialize..."
sleep 12

# 3. Domain Services
echo ""
echo ">>> Step 3/5: Starting Domain Services (Patient, Appointment, Analytics)..."
docker compose up -d patient-service appointment-service analytics-service
echo "Giving JVM services 15s to initialize..."
sleep 15

# 4. API Gateway
echo ""
echo ">>> Step 4/5: Starting API Gateway..."
docker compose up -d api-gateway
echo "Giving Gateway 10s to warm up..."
sleep 10

# 5. Monitoring & Reverse Proxy
echo ""
echo ">>> Step 5/5: Starting Prometheus, Grafana & Nginx..."
docker compose up -d prometheus grafana nginx

echo ""
echo "=========================================================="
echo " All services started successfully!                       "
echo "=========================================================="
docker compose ps
