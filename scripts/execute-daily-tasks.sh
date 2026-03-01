#!/bin/bash
# daily-tasks.json を読んでタスクを実行する（1週間ロック付き）
SITE_DIR="/home/ken/37design-astro-site"
echo "=== タスク実行開始 ==="
python3 "${SITE_DIR}/scripts/execute-tasks.py"
