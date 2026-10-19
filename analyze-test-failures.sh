#!/bin/bash
# Detailed test failure analyzer for RHELAI E2E tests

set -euo pipefail

LOG_FILE="${1:-test-logs/rhelai-docker-e2e-$(date +%Y%m%d)*.log}"
LOG_FILE=$(ls -t $LOG_FILE 2>/dev/null | head -1 || echo "")

if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
  echo "❌ No log file found matching: ${1:-test-logs/rhelai-docker-e2e-*.log}"
  echo ""
  echo "Usage: $0 [log-file-path]"
  echo ""
  echo "Available log files:"
  ls -1t test-logs/rhelai-*.log 2>/dev/null | head -5 || echo "  (none found)"
  exit 1
fi

echo "📊 Analyzing: $LOG_FILE"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test Summary
echo "📈 TEST SUMMARY"
echo "───────────────────────────────────────────────────────────"
grep -E "scenarios? passed.*failed.*error.*skipped" "$LOG_FILE" | tail -1
echo ""

# Failed Scenarios by Type
echo "❌ FAILURE BREAKDOWN"
echo "───────────────────────────────────────────────────────────"

echo ""
echo "1️⃣  Question Validity Failures (pizza questions not rejected):"
grep -c "What is the best topping for.*pizza.*doesn't contain.*I can only answer questions about OpenShift" "$LOG_FILE" 2>/dev/null || echo "  0 failures"

echo ""
echo "2️⃣  PII Redaction Failures (numbers not redacted):"
grep -c "doesn't contain.*\[NUM\]" "$LOG_FILE" 2>/dev/null || echo "  0 failures"

echo ""
echo "3️⃣  Shield Not Found Errors:"
grep -c "Shield.*does not exist" "$LOG_FILE" 2>/dev/null || echo "  0 failures"

echo ""
echo "4️⃣  Prompt Injection Not Blocked:"
grep -c "doesn't contain.*I cannot return that response" "$LOG_FILE" 2>/dev/null || echo "  0 failures"

echo ""
echo "5️⃣  Other Failures:"
OTHER_FAILURES=$(grep -c "ASSERT FAILED" "$LOG_FILE" 2>/dev/null || echo "0")
KNOWN_FAILURES=$((
  $(grep -c "What is the best topping for.*pizza.*doesn't contain.*I can only answer questions about OpenShift" "$LOG_FILE" 2>/dev/null || echo "0") +
  $(grep -c "doesn't contain.*\[NUM\]" "$LOG_FILE" 2>/dev/null || echo "0") +
  $(grep -c "Shield.*does not exist" "$LOG_FILE" 2>/dev/null || echo "0") +
  $(grep -c "doesn't contain.*I cannot return that response" "$LOG_FILE" 2>/dev/null || echo "0")
))
echo "  $((OTHER_FAILURES - KNOWN_FAILURES)) failures"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🔍 SAMPLE FAILURES (first 5):"
echo "───────────────────────────────────────────────────────────"
grep -B 2 "AUTO-RETRY SCENARIO FAILED" "$LOG_FILE" | head -20
echo ""

echo "═══════════════════════════════════════════════════════════"
echo ""
echo "💡 ROOT CAUSE ANALYSIS:"
echo "───────────────────────────────────────────────────────────"

# Check which shields are configured
echo ""
echo "Configured Shields:"
if grep -q "\"shields\": \[\]" "$LOG_FILE"; then
  echo "  ⚠️  EMPTY - No shields configured in RHELAI mode!"
else
  grep -o '{"name": "[^"]*", "provider_id": "[^"]*"' "$LOG_FILE" | head -5 || echo "  (unable to extract)"
fi

echo ""
echo "Expected Shields for Tests:"
echo "  ✓ question_validity (off-topic question filter)"
echo "  ✓ pii-redaction (PII redaction)"
echo "  ✓ granite-guardian (prompt injection blocker)"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🔧 NEXT STEPS:"
echo "───────────────────────────────────────────────────────────"
echo "1. Check if shields are configured in tests/e2e/configuration/server-mode/lightspeed-stack-rhelai.yaml"
echo "2. Verify shields use vLLM model (not OpenAI) for question_validity"
echo "3. Enable debug logging: OGX_LOGGING=DEBUG LIGHTSPEED_LOG_LEVEL=DEBUG"
echo "4. Check shield initialization logs in container output"
echo ""
