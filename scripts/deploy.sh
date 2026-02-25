#!/bin/bash
# 37Design Marketing OS - Deploy Script
# Usage: ./scripts/deploy.sh [branch]
# Called by n8n webhook or manually

set -euo pipefail

PROJECT_DIR="$HOME/37design-astro-site"
BRANCH="${1:-main}"
LOG_FILE="$PROJECT_DIR/deploy.log"
DEPLOY_TARGET="xserver"  # xserver | lolipop | local

# Xserver settings (37design.co.jp) - PRIMARY
XSERVER_USER="server37"
XSERVER_HOST="sv2023.xserver.jp"
XSERVER_PORT="10022"
XSERVER_KEY="$HOME/.ssh/server37.key"
XSERVER_PATH="~/37design.co.jp/public_html/"

# Lolipop settings (backup)
LOLIPOP_USER="noor.jp-37design"
LOLIPOP_HOST="ssh.lolipop.jp"
LOLIPOP_PORT="2222"
LOLIPOP_PASS="${LOLIPOP_PASS:?LOLIPOP_PASS環境変数を設定してください}"
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

# 4. Safety check: dist/ が空でないことを確認
FILE_COUNT=$(find "$PROJECT_DIR/dist/" -type f | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -lt 10 ]; then
  log "ERROR: dist/ のファイル数が少なすぎます (${FILE_COUNT} files)。デプロイを中止します。"
  exit 1
fi
log "dist/ ファイル数: ${FILE_COUNT}"

# 5. Deploy
case "$DEPLOY_TARGET" in
  xserver)
    log "Deploying to Xserver (37design.co.jp)..."
    rsync -avz --delete \
      -e "ssh -i $XSERVER_KEY -p $XSERVER_PORT -o StrictHostKeyChecking=accept-new" \
      "$PROJECT_DIR/dist/" \
      "$XSERVER_USER@$XSERVER_HOST:$XSERVER_PATH"
    ;;
  lolipop)
    log "Deploying to Lolipop (37design.co.jp)..."
    sshpass -p "$LOLIPOP_PASS" rsync -avz --delete \
      -e "ssh -p $LOLIPOP_PORT -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new" \
      "$PROJECT_DIR/dist/" \
      "$LOLIPOP_USER@$LOLIPOP_HOST:$LOLIPOP_PATH"
    ;;
  local)
    log "Local deploy: files available at $PROJECT_DIR/dist/"
    ;;
esac

log "=== Deploy completed: $COMMIT ==="
echo "$COMMIT"
