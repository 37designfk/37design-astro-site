#!/bin/bash
set -euo pipefail

# Marketing OS End-to-End Pipeline Test
# Run via: ssh u "bash ~/37design-astro-site/scripts/marketing-os-test-pipeline.sh [--cleanup]"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

PSQL="docker exec docker-db_postgres-1 psql -U postgres -d marketing_os -t -c"
TASK_KEY="blog:test-pipeline-check"
WEBHOOK_URL="http://localhost:5678/webhook/37design-decision"
POLL_INTERVAL=10
MAX_WAIT=300  # 5 minutes

CLEANUP=false
for arg in "$@"; do
  case "$arg" in
    --cleanup) CLEANUP=true ;;
  esac
done

# ──────────────────────────────────────────────
# Cleanup mode
# ──────────────────────────────────────────────
if [ "$CLEANUP" = true ]; then
  echo -e "${BOLD}[Cleanup] Removing test task and key...${NC}"
  $PSQL "DELETE FROM task_queue WHERE task_key = '$TASK_KEY';" 2>/dev/null || true
  $PSQL "DELETE FROM active_task_keys WHERE task_key = '$TASK_KEY';" 2>/dev/null || true
  echo -e "  ${GREEN}✓${NC} Cleanup complete."
  exit 0
fi

echo -e "${BOLD}=== Marketing OS Pipeline Test ===${NC}"
echo ""

# ──────────────────────────────────────────────
# Step 1: Insert test task into task_queue
# ──────────────────────────────────────────────
echo -e "${BOLD}[1/4] Inserting test task into task_queue...${NC}"

# Remove any leftover test data first
$PSQL "DELETE FROM task_queue WHERE task_key = '$TASK_KEY';" 2>/dev/null || true
$PSQL "DELETE FROM active_task_keys WHERE task_key = '$TASK_KEY';" 2>/dev/null || true

task_id=$($PSQL "
INSERT INTO task_queue (client_id, task_type, priority, payload, task_key)
SELECT id, 'blog_generate', 50,
  '{\"target_keyword\":\"テスト記事\",\"slug\":\"test-pipeline-check\",\"title\":\"パイプラインテスト記事\",\"description\":\"自動パイプラインの動作確認用テスト記事\",\"category\":\"AI\",\"tags\":[\"テスト\"]}'::jsonb,
  '$TASK_KEY'
FROM clients WHERE slug = '37design'
RETURNING id;
" 2>/dev/null | tr -d ' ')

if [ -z "$task_id" ]; then
  echo -e "  ${RED}✗${NC} Failed to insert test task. Is the '37design' client configured?"
  exit 1
fi
echo -e "  ${GREEN}✓${NC} Task inserted with id: $task_id"

# ──────────────────────────────────────────────
# Step 2: Insert into active_task_keys
# ──────────────────────────────────────────────
echo -e "${BOLD}[2/4] Inserting into active_task_keys...${NC}"

$PSQL "
INSERT INTO active_task_keys (client_id, task_key, status)
SELECT id, '$TASK_KEY', 'attached'
FROM clients WHERE slug = '37design';
" 2>/dev/null

echo -e "  ${GREEN}✓${NC} active_task_key inserted."

# ──────────────────────────────────────────────
# Step 3: Trigger WF3 (decision webhook)
# ──────────────────────────────────────────────
echo -e "${BOLD}[3/4] Triggering WF3 decision webhook...${NC}"

http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H 'Content-Type: application/json' -d '{}')

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
  echo -e "  ${GREEN}✓${NC} Webhook triggered (HTTP $http_code)"
elif [ "$http_code" -ge 400 ]; then
  echo -e "  ${RED}✗${NC} Webhook returned HTTP $http_code"
  echo -e "  ${YELLOW}⚠${NC} Continuing to monitor anyway..."
else
  echo -e "  ${YELLOW}⚠${NC} Webhook returned HTTP $http_code"
fi

# ──────────────────────────────────────────────
# Step 4: Monitor task status
# ──────────────────────────────────────────────
echo -e "${BOLD}[4/4] Monitoring task status (max ${MAX_WAIT}s)...${NC}"

elapsed=0
result="TIMEOUT"

while [ "$elapsed" -lt "$MAX_WAIT" ]; do
  row=$($PSQL "SELECT id, status, task_type, COALESCE(error_log, '') FROM task_queue WHERE task_key = '$TASK_KEY';" 2>/dev/null || echo "")

  if [ -n "$row" ]; then
    status=$(echo "$row" | awk -F'|' '{print $2}' | tr -d ' ')

    case "$status" in
      done)
        echo -e "  ${GREEN}✓${NC} Task status: done (${elapsed}s elapsed)"
        result="PASS"
        break
        ;;
      running)
        echo -e "  ${GREEN}✓${NC} Task status: running (${elapsed}s elapsed)"
        result="PASS"
        break
        ;;
      failed)
        error_log=$(echo "$row" | awk -F'|' '{print $4}' | sed 's/^ *//')
        echo -e "  ${RED}✗${NC} Task status: failed (${elapsed}s elapsed)"
        if [ -n "$error_log" ]; then
          echo -e "  ${RED}✗${NC} Error: $error_log"
        fi
        result="FAIL"
        break
        ;;
      pending)
        echo -e "  ... pending (${elapsed}s / ${MAX_WAIT}s)"
        ;;
      *)
        echo -e "  ${YELLOW}⚠${NC} Unknown status: $status"
        ;;
    esac
  else
    echo -e "  ${RED}✗${NC} Task not found in queue!"
    result="FAIL"
    break
  fi

  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
done

# ──────────────────────────────────────────────
# Final Report
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== Result ===${NC}"
case "$result" in
  PASS)
    echo -e "  ${GREEN}✓ PASS${NC} - Pipeline is working. Task reached '$status' status."
    echo -e "  Run with ${BOLD}--cleanup${NC} to remove test data."
    ;;
  FAIL)
    echo -e "  ${RED}✗ FAIL${NC} - Pipeline encountered an error."
    echo -e "  Run with ${BOLD}--cleanup${NC} to remove test data."
    ;;
  TIMEOUT)
    echo -e "  ${YELLOW}⚠ TIMEOUT${NC} - Task still pending after ${MAX_WAIT}s."
    echo -e "  This may indicate WF3 did not pick up the task."
    echo -e "  Run with ${BOLD}--cleanup${NC} to remove test data."
    ;;
esac

exit 0
