#!/bin/bash
set -euo pipefail

# Marketing OS Status Check
# Run via: ssh u "bash ~/37design-astro-site/scripts/marketing-os-status.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

section() { echo -e "\n${BOLD}[$1]${NC}"; }

PSQL="docker exec docker-db_postgres-1 psql -U postgres -d marketing_os -t -c"

# ──────────────────────────────────────────────
section "Docker Containers"
# ──────────────────────────────────────────────
for container in n8n docker-db_postgres-1 growthbook growthbook-mongo; do
  status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not found")
  if [ "$status" = "running" ]; then
    ok "$container: running"
  elif [ "$status" = "not found" ]; then
    fail "$container: not found"
  else
    warn "$container: $status"
  fi
done

# ──────────────────────────────────────────────
section "Ollama"
# ──────────────────────────────────────────────
if systemctl is-active --quiet ollama 2>/dev/null; then
  ok "ollama service: active"
else
  fail "ollama service: inactive"
fi

models=$(ollama list 2>/dev/null || echo "")
if [ -n "$models" ]; then
  model_count=$(echo "$models" | tail -n +2 | wc -l | tr -d ' ')
  ok "Models loaded: $model_count"
  echo "$models" | tail -n +2 | while IFS= read -r line; do
    echo "      $line"
  done
else
  warn "Could not list Ollama models"
fi

# ──────────────────────────────────────────────
section "PostgreSQL (marketing_os)"
# ──────────────────────────────────────────────

# Total table count
table_count=$($PSQL "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
if [ -n "$table_count" ] && [ "$table_count" -gt 0 ] 2>/dev/null; then
  ok "Tables in public schema: $table_count"
else
  fail "Cannot query marketing_os database"
fi

# task_queue stats
echo -e "  ${BOLD}task_queue:${NC}"
task_stats=$($PSQL "SELECT status, COUNT(*) FROM task_queue GROUP BY status ORDER BY status;" 2>/dev/null || echo "")
if [ -n "$task_stats" ]; then
  echo "$task_stats" | while IFS='|' read -r status count; do
    status=$(echo "$status" | tr -d ' ')
    count=$(echo "$count" | tr -d ' ')
    [ -z "$status" ] && continue
    case "$status" in
      done)    ok "  $status: $count" ;;
      pending) warn "  $status: $count" ;;
      running) warn "  $status: $count" ;;
      failed)  fail "  $status: $count" ;;
      *)       echo "      $status: $count" ;;
    esac
  done
else
  warn "  No tasks in queue"
fi

# active_task_keys count
atk_count=$($PSQL "SELECT COUNT(*) FROM active_task_keys;" 2>/dev/null | tr -d ' ')
ok "active_task_keys: $atk_count"

# page_locks
active_locks=$($PSQL "SELECT COUNT(*) FROM page_locks WHERE released_at IS NULL;" 2>/dev/null | tr -d ' ')
expiring_24h=$($PSQL "SELECT COUNT(*) FROM page_locks WHERE released_at IS NULL AND expires_at < NOW() + INTERVAL '24 hours';" 2>/dev/null | tr -d ' ')
if [ "${active_locks:-0}" -gt 0 ] 2>/dev/null; then
  warn "page_locks: $active_locks active ($expiring_24h expiring within 24h)"
else
  ok "page_locks: $active_locks active"
fi

# daily_limits
echo -e "  ${BOLD}daily_limits:${NC}"
limits=$($PSQL "SELECT limit_key, current_usage, max_limit FROM daily_limits WHERE limit_date = CURRENT_DATE ORDER BY limit_key;" 2>/dev/null || echo "")
if [ -n "$limits" ]; then
  echo "$limits" | while IFS='|' read -r key usage max_val; do
    key=$(echo "$key" | tr -d ' ')
    usage=$(echo "$usage" | tr -d ' ')
    max_val=$(echo "$max_val" | tr -d ' ')
    [ -z "$key" ] && continue
    if [ "$usage" -ge "$max_val" ] 2>/dev/null; then
      fail "  $key: $usage / $max_val (LIMIT REACHED)"
    elif [ "$usage" -ge $((max_val * 80 / 100)) ] 2>/dev/null; then
      warn "  $key: $usage / $max_val"
    else
      ok "  $key: $usage / $max_val"
    fi
  done
else
  ok "  No limits set for today"
fi

# ──────────────────────────────────────────────
section "n8n"
# ──────────────────────────────────────────────
n8n_status=$(docker inspect -f '{{.State.Status}}' n8n 2>/dev/null || echo "not found")
if [ "$n8n_status" = "running" ]; then
  ok "n8n container: running"
  wf_count=$(docker exec n8n n8n export:workflow --all --output=/tmp/n8n_wf_check.json 2>/dev/null && \
    docker exec n8n python3 -c "import json; data=json.load(open('/tmp/n8n_wf_check.json')); print(len(data))" 2>/dev/null || \
    docker exec n8n sh -c "n8n export:workflow --all 2>/dev/null | python3 -c \"import sys,json; print(len(json.load(sys.stdin)))\"" 2>/dev/null || \
    echo "unknown")
  ok "Workflows: $wf_count"
else
  fail "n8n container: $n8n_status"
fi

# ──────────────────────────────────────────────
section "Disk Space"
# ──────────────────────────────────────────────
disk_info=$(df -h / | tail -1)
disk_use=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
disk_line=$(echo "$disk_info" | awk '{print $3 " used / " $2 " total (" $5 " used)"}')
if [ "$disk_use" -ge 90 ] 2>/dev/null; then
  fail "Disk: $disk_line"
elif [ "$disk_use" -ge 75 ] 2>/dev/null; then
  warn "Disk: $disk_line"
else
  ok "Disk: $disk_line"
fi

# ──────────────────────────────────────────────
section "Recent Activity"
# ──────────────────────────────────────────────
DEPLOY_LOG="$HOME/37design-astro-site/deploy.log"
if [ -f "$DEPLOY_LOG" ]; then
  ok "Last 5 deploy log entries:"
  tail -5 "$DEPLOY_LOG" | while IFS= read -r line; do
    echo "      $line"
  done
else
  warn "No deploy.log found at $DEPLOY_LOG"
fi

# ──────────────────────────────────────────────
section "Git Status"
# ──────────────────────────────────────────────
REPO_DIR="$HOME/37design-astro-site"
if [ -d "$REPO_DIR/.git" ]; then
  branch=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  last_commit=$(git -C "$REPO_DIR" log -1 --format="%h %s (%cr)" 2>/dev/null || echo "unknown")
  ok "Branch: $branch"
  ok "Last commit: $last_commit"
else
  warn "No git repository at $REPO_DIR"
fi

echo ""
echo -e "${BOLD}Status check complete.${NC}"
