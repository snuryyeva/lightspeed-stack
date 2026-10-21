#!/bin/bash
# Run RHEL AI E2E tests locally using Docker Compose
# Connects to port-forwarded vLLM from OpenShift
set -euo pipefail

echo "=========================================="
echo "RHEL AI E2E Tests - Local Docker Setup"
echo "=========================================="
echo ""

# Source environment variables first to check VLLM_URL
if [ -f .env.rhelai ]; then
  echo "📝 Loading environment from .env.rhelai..."
  source .env.rhelai
else
  echo "❌ ERROR: .env.rhelai file not found"
  exit 1
fi

# Check if vLLM is accessible (either local port-forward or external URL)
echo "🔍 Checking vLLM accessibility..."
if [[ "$VLLM_URL" == https://* ]]; then
  # Using external HTTPS URL
  if curl -sk -f --max-time 5 -H "Authorization: Bearer ${VLLM_API_KEY}" "${VLLM_URL}/v1/models" >/dev/null 2>&1; then
    echo "✅ vLLM is accessible at ${VLLM_URL}"
  else
    echo "❌ ERROR: Cannot reach vLLM at ${VLLM_URL}"
    echo ""
    echo "Check if the external vLLM endpoint is accessible:"
    echo "  curl -sk -H \"Authorization: Bearer \${VLLM_API_KEY}\" ${VLLM_URL}/v1/models"
    exit 1
  fi
elif curl -s -f --max-time 3 http://localhost:8000/v1/health >/dev/null 2>&1 || \
     curl -s --max-time 3 http://localhost:8000/v1/health 2>&1 | grep -q "Unauthorized"; then
  echo "✅ vLLM is accessible at localhost:8000"
else
  echo "❌ ERROR: Cannot reach vLLM at localhost:8000"
  echo ""
  echo "You need to port-forward vLLM first:"
  echo "  oc port-forward -n ls-evals pod/vllm-server 8000:8000"
  echo ""
  echo "Or check if the port-forward is still running:"
  echo "  ps aux | grep 'port-forward.*8000'"
  exit 1
fi

# Verify required environment variables
: "${VLLM_URL:?ERROR: VLLM_URL not set}"
: "${VLLM_API_KEY:?ERROR: VLLM_API_KEY not set}"
: "${VLLM_MODEL:?ERROR: VLLM_MODEL not set}"
: "${OPENAI_API_KEY:?ERROR: OPENAI_API_KEY not set (required as fallback)}"

echo ""
echo "Configuration:"
echo "  VLLM_URL: $VLLM_URL"
echo "  VLLM_MODEL: $VLLM_MODEL"
echo "  OPENAI_API_KEY: ${OPENAI_API_KEY:0:20}..."
echo ""

# Export for docker-compose (docker compose needs these in the environment, not just sourced)
export VLLM_URL
export VLLM_API_KEY
export VLLM_MODEL
export RHEL_AI_URL
export RHEL_AI_PORT
export RHEL_AI_API_KEY
export RHEL_AI_MODEL
export OPENAI_API_KEY
export FAISS_VECTOR_STORE_ID

# Build images if needed
echo "🔨 Building Docker images (if needed)..."
docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml build

# Start services
echo ""
echo "🚀 Starting services..."
docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml up -d

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to be healthy..."
for service in ogx lightspeed-stack; do
  echo "   Waiting for $service..."
  timeout=120
  elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml ps --format json "$service" 2>/dev/null | \
       grep -q '"Health":"healthy"'; then
      echo "   ✅ $service is healthy"
      break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  if [ $elapsed -ge $timeout ]; then
    echo "   ❌ $service did not become healthy in ${timeout}s"
    echo ""
    echo "Logs from $service:"
    docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml logs --tail=50 "$service"
    exit 1
  fi
done

echo ""
echo "=========================================="
echo "✅ Services are ready!"
echo "=========================================="
echo ""
echo "Service endpoints:"
echo "  OGX: http://localhost:8321"
echo "  Lightspeed Stack: http://localhost:8080"
echo ""
echo "To run E2E tests:"
echo "  uv run make test-e2e"
echo ""
echo "To view logs:"
echo "  docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml logs -f"
echo ""
echo "To stop services:"
echo "  docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml down"
echo ""
