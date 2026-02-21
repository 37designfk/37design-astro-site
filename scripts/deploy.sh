#!/bin/bash
# 37Design Marketing OS - Deploy Script
# Usage: ./scripts/deploy.sh [branch]
# Called by n8n webhook or manually

set -euo pipefail

PROJECT_DIR="$HOME/37design-astro-site"
BRANCH="${1:-main}"
LOG_FILE="$PROJECT_DIR/deploy.log"
DEPLOY_TARGET="lolipop"  # lolipop | cloudflare | local

# Lolipop settings (37design.co.jp)
LOLIPOP_USER="noor.jp-37design"
LOLIPOP_HOST="ssh.lolipop.jp"
LOLIPOP_PORT="2222"
LOLIPOP_PASS="6fgp7xayMdiobgPTypKuhDf4wansjvOP"
LOLIPOP_PATH="~/web/37design.co.jp/"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Deploy started (branch: $BRANCH) ==="

cd "$PROJECT_DIR"

# 1. Pull latest
log "Pulling latest from origin/$BRANCH..."
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

COMMIT=$(git rev-parse --short HEAD)
log "Current commit: $COMMIT"

# 2. Install dependencies (if package-lock changed)
if git diff HEAD~1 --name-only | grep -q "package-lock.json"; then
  log "package-lock.json changed, running npm install..."
  npm install
fi

# 3. Build
log "Building..."
if npm run build 2>&1 | tee -a "$LOG_FILE"; then
  log "Build successful"
else
  log "ERROR: Build failed!"
  exit 1
fi

# 4. Deploy
case "$DEPLOY_TARGET" in
  lolipop)
    log "Deploying to Lolipop (37design.co.jp)..."
    sshpass -p "$LOLIPOP_PASS" rsync -avz --delete \
      -e "ssh -p $LOLIPOP_PORT -o PubkeyAuthentication=no -o StrictHostKeyChecking=no" \
      "$PROJECT_DIR/dist/" \
      "$LOLIPOP_USER@$LOLIPOP_HOST:$LOLIPOP_PATH"
    ;;
  cloudflare)
    log "Cloudflare Pages deploy (via git push - already done)"
    ;;
  local)
    log "Local deploy: files available at $PROJECT_DIR/dist/"
    ;;
esac

log "=== Deploy completed: $COMMIT ==="
echo "$COMMIT"
