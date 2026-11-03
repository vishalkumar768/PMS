#!/bin/bash
set -e

echo "=========================================================="
echo " PMS Low-Memory Deployment Script                         "
echo "=========================================================="

SERVICES=(
  postgres
  redis
  kafka
  auth-service
  billing-service
  analytics-service
  patient-service
  appointment-service
  api-gateway
  nginx
)

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

# --- STEP 0: Sequential Pull ---
echo ""
echo ">>> Step 0: Pulling Docker images ONE BY ONE (prevents CPU & I/O thrashing)..."
for svc in "${SERVICES[@]}"; do
  echo "==> Pulling image for: $svc"
  docker compose pull "$svc"
done
echo ">>> All images pulled successfully!"

# --- STEP 1: Base Infrastructure ---
echo ""
echo ">>> Step 1/4: Starting Databases & Messaging (Postgres, Redis, Kafka)..."
docker compose up -d postgres redis kafka

wait_for_healthy postgres
wait_for_healthy kafka
sleep 2

# --- STEP 2: Core Dependencies ---
echo ""
echo ">>> Step 2/4: Starting Core Services (Auth & Billing)..."
docker compose up -d auth-service billing-service
echo "Giving JVM services 12s to initialize..."
sleep 12

# --- STEP 3: Domain Services ---
echo ""
echo ">>> Step 3/4: Starting Domain Services (Patient, Appointment, Analytics)..."
docker compose up -d patient-service appointment-service analytics-service
echo "Giving JVM services 15s to initialize..."
sleep 15

# --- STEP 4: API Gateway & Reverse Proxy ---
echo ""
echo ">>> Step 4/4: Starting API Gateway & Nginx..."
docker compose up -d api-gateway
echo "Giving Gateway 10s to warm up..."
sleep 10
docker compose up -d nginx

echo ""
echo "=========================================================="
echo " All services started successfully!                       "
echo "=========================================================="
docker compose ps
