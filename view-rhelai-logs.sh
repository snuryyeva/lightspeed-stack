#!/bin/bash
# Helper script to view RHEL AI Docker logs

set -euo pipefail

COMPOSE_CMD="docker compose -f docker-compose.yaml -f docker-compose.rhelai.yaml"

show_help() {
  cat << EOF
RHEL AI Docker Logs Viewer

Usage: ./view-rhelai-logs.sh [COMMAND]

Commands:
  live              Watch all container logs in real-time (Ctrl+C to stop)
  live-ogx          Watch OGX logs only
  live-lcs          Watch Lightspeed Stack logs only

  dump              Save all container logs to files
  dump-ogx          Save OGX logs to ogx-full.log
  dump-lcs          Save LCS logs to lcs-full.log

  tail              Show last 100 lines from all containers
  tail-ogx          Show last 100 lines from OGX
  tail-lcs          Show last 100 lines from LCS

  errors            Show errors from all containers
  errors-ogx        Show errors from OGX only
  errors-lcs        Show errors from LCS only

  status            Show container status
  help              Show this help message

Examples:
  # Watch logs in real-time
  ./view-rhelai-logs.sh live

  # Save all logs to files
  ./view-rhelai-logs.sh dump

  # Check for errors
  ./view-rhelai-logs.sh errors

EOF
}

case "${1:-help}" in
  live)
    echo "📺 Watching all container logs (Ctrl+C to stop)..."
    $COMPOSE_CMD logs -f
    ;;
  live-ogx)
    echo "📺 Watching OGX logs (Ctrl+C to stop)..."
    $COMPOSE_CMD logs -f ogx
    ;;
  live-lcs)
    echo "📺 Watching Lightspeed Stack logs (Ctrl+C to stop)..."
    $COMPOSE_CMD logs -f lightspeed-stack
    ;;

  dump)
    echo "💾 Dumping all container logs..."
    $COMPOSE_CMD logs > container-logs-all.log
    $COMPOSE_CMD logs ogx > container-logs-ogx.log
    $COMPOSE_CMD logs lightspeed-stack > container-logs-lcs.log
    echo "✅ Logs saved:"
    echo "   - container-logs-all.log"
    echo "   - container-logs-ogx.log"
    echo "   - container-logs-lcs.log"
    ;;
  dump-ogx)
    echo "💾 Dumping OGX logs..."
    $COMPOSE_CMD logs ogx > container-logs-ogx.log
    echo "✅ Saved to: container-logs-ogx.log"
    ;;
  dump-lcs)
    echo "💾 Dumping Lightspeed Stack logs..."
    $COMPOSE_CMD logs lightspeed-stack > container-logs-lcs.log
    echo "✅ Saved to: container-logs-lcs.log"
    ;;

  tail)
    echo "📄 Last 100 lines from all containers:"
    echo ""
    $COMPOSE_CMD logs --tail=100
    ;;
  tail-ogx)
    echo "📄 Last 100 lines from OGX:"
    echo ""
    $COMPOSE_CMD logs --tail=100 ogx
    ;;
  tail-lcs)
    echo "📄 Last 100 lines from Lightspeed Stack:"
    echo ""
    $COMPOSE_CMD logs --tail=100 lightspeed-stack
    ;;

  errors)
    echo "❌ Errors from all containers:"
    echo ""
    $COMPOSE_CMD logs | grep -iE "error|exception|traceback|failed" || echo "No errors found"
    ;;
  errors-ogx)
    echo "❌ Errors from OGX:"
    echo ""
    $COMPOSE_CMD logs ogx | grep -iE "error|exception|traceback|failed" || echo "No errors found"
    ;;
  errors-lcs)
    echo "❌ Errors from Lightspeed Stack:"
    echo ""
    $COMPOSE_CMD logs lightspeed-stack | grep -iE "error|exception|traceback|failed" || echo "No errors found"
    ;;

  status)
    echo "📊 Container status:"
    echo ""
    $COMPOSE_CMD ps
    ;;

  help|--help|-h)
    show_help
    ;;

  *)
    echo "❌ Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
esac
