#!/bin/bash
# 37Design Marketing OS - Deploy Script
# Usage: ./scripts/deploy.sh [branch]
# Deploy: git push → Cloudflare Pages auto-build

set -uo pipefail

PROJECT_DIR="$HOME/37design-astro-site"
BRANCH="${1:-main}"
LOG_FILE="$PROJECT_DIR/deploy.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Deploy started (branch: $BRANCH) ==="

cd "$PROJECT_DIR"

COMMIT=$(git rev-parse --short HEAD)
log "Current commit: $COMMIT"

# 1. ローカルビルドテスト
log "Building (local check)..."
if npm run build 2>&1 | tee -a "$LOG_FILE"; then
  log "Build successful"
else
  log "ERROR: Build failed!"
  exit 1
fi

# 2. Safety check
FILE_COUNT=$(find "$PROJECT_DIR/dist/" -type f | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -lt 10 ]; then
  log "ERROR: dist/ のファイル数が少なすぎます (${FILE_COUNT} files)。"
  exit 1
fi
log "dist/ ファイル数: ${FILE_COUNT}"

# 3. GitHub push → Cloudflare Pages 自動デプロイ
log "Pushing to GitHub (Cloudflare Pages auto-deploy)..."
if git push origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
  log "=== Deploy completed: $COMMIT ==="
  echo "$COMMIT"
else
  log "ERROR: git push failed!"
  exit 1
fi
