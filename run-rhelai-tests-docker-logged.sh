#!/bin/bash
# Run RHEL AI E2E tests locally with Docker Compose and save logs
#
# Usage:
#   ./run-rhelai-tests-docker-logged.sh                              # Run all tests
#   ./run-rhelai-tests-docker-logged.sh tests/e2e/features/foo.feature  # Run specific feature
#
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

# Accept optional feature file argument, default to full test list
FEATURE_FILE="${1:-@tests/e2e/test_list.txt}"

# Run E2E tests with specified feature file
# Skip @multimodal tests since RHEL AI uses text-only models (Llama-3.1-8B-Instruct)
if [[ "$FEATURE_FILE" == "@tests/e2e/test_list.txt" ]]; then
  echo "🧪 Running ALL E2E tests from test list (skipping multimodal)..." | tee -a "$LOG_FILE"
else
  echo "🧪 Running specific feature: $FEATURE_FILE" | tee -a "$LOG_FILE"
fi

uv run behave --color --format pretty --tags=-skip --tags=-multimodal -D dump_errors=true "$FEATURE_FILE" 2>&1 | tee -a "$LOG_FILE"
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
