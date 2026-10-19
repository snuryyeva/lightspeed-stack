#!/bin/bash
# Run RHEL AI E2E tests locally with Docker Compose and save logs
set -euo pipefail

# Create logs directory
LOG_DIR="test-logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/rhelai-docker-e2e-${TIMESTAMP}.log"

echo "=========================================="
echo "RHEL AI E2E Tests - Local Docker"
echo "=========================================="
echo ""
echo "📝 Logs will be saved to: $LOG_FILE"
echo ""

# Function to cleanup on exit
cleanup() {
  echo ""
  echo "🧹 Cleaning up..."
  docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml logs >> "$LOG_FILE" 2>&1 || true
  docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml down >> "$LOG_FILE" 2>&1 || true
  echo "📁 Final logs saved to: $LOG_FILE"
}

trap cleanup EXIT

# Run setup script and capture output
echo "Starting services..." | tee -a "$LOG_FILE"
./run-rhelai-local-docker.sh 2>&1 | tee -a "$LOG_FILE"
SETUP_EXIT=${PIPESTATUS[0]}

if [ $SETUP_EXIT -ne 0 ]; then
  echo "❌ Setup failed (exit code: $SETUP_EXIT)" | tee -a "$LOG_FILE"
  exit $SETUP_EXIT
fi

echo ""
echo "=========================================="
echo "Running E2E Tests"
echo "=========================================="
echo "" | tee -a "$LOG_FILE"

# Source environment
source .env.rhelai

# Run E2E tests (use test-e2e-local on macOS for BSD script compatibility)
echo "🧪 Running E2E tests..." | tee -a "$LOG_FILE"
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "ℹ️  macOS detected - using test-e2e-local (BSD script compatibility)" | tee -a "$LOG_FILE"
  uv run make test-e2e-local 2>&1 | tee -a "$LOG_FILE"
else
  uv run make test-e2e 2>&1 | tee -a "$LOG_FILE"
fi
TEST_EXIT=${PIPESTATUS[0]}

echo "" | tee -a "$LOG_FILE"
if [ $TEST_EXIT -eq 0 ]; then
  echo "✅ Tests PASSED" | tee -a "$LOG_FILE"
else
  echo "❌ Tests FAILED (exit code: $TEST_EXIT)" | tee -a "$LOG_FILE"

  # Capture service logs on failure
  echo "" | tee -a "$LOG_FILE"
  echo "=========================================="
  echo "Service Logs (Last 100 lines each)"
  echo "==========================================" | tee -a "$LOG_FILE"

  for service in ogx lightspeed-stack; do
    echo ""
    echo "--- $service logs ---" | tee -a "$LOG_FILE"
    docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml logs --tail=100 "$service" 2>&1 | tee -a "$LOG_FILE"
  done
fi

echo ""
echo "📁 Full logs saved to: $LOG_FILE"
exit $TEST_EXIT
