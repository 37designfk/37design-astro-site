#!/bin/bash
# Claude Code usage を n8n ダッシュボードに同期する
# Stop フックから自動呼び出し or 手動実行

STATS_FILE="$HOME/.claude/stats-cache.json"
N8N_ENDPOINT="https://n8n-onprem.37d.jp/webhook/37design-claude-usage"

if [ ! -f "$STATS_FILE" ]; then
  exit 0
fi

python3 << 'EOF'
import json, urllib.request, urllib.parse
from datetime import datetime

STATS_FILE = f"{__import__('os').path.expanduser('~')}/.claude/stats-cache.json"
N8N_ENDPOINT = "https://n8n-onprem.37d.jp/webhook/37design-claude-usage"

with open(STATS_FILE) as f:
    d = json.load(f)

now = datetime.now()
month_prefix = now.strftime('%Y-%m')

# 今月の日別トークン
monthly_daily = []
month_total = {}
for day in d.get('dailyModelTokens', []):
    if day['date'].startswith(month_prefix):
        day_total = sum(day['tokensByModel'].values())
        monthly_daily.append({'date': day['date'], 'tokens': day_total, 'byModel': day['tokensByModel']})
        for model, tokens in day['tokensByModel'].items():
            # opus / sonnet / haiku に短縮
            for key in ['opus', 'sonnet', 'haiku']:
                if key in model:
                    month_total[key] = month_total.get(key, 0) + tokens
                    break

# 直近30日のアクティビティ
recent_activity = [a for a in d.get('dailyActivity', []) if a['date'] >= now.strftime('%Y-%m-01')]

# Max プランのトークン上限（目安: Opusで約100M tokens/月）
OPUS_LIMIT = 100_000_000
opus_used = month_total.get('opus', 0)
usage_pct = round(opus_used / OPUS_LIMIT * 100, 1) if OPUS_LIMIT > 0 else 0

payload = {
    'updated_at': now.isoformat(),
    'billing_period': month_prefix,
    'month_total_tokens': sum(month_total.values()),
    'month_by_model': month_total,
    'monthly_daily': monthly_daily[-14:],  # 直近14日
    'recent_activity': recent_activity,
    'total_sessions': d.get('totalSessions', 0),
    'total_messages': d.get('totalMessages', 0),
    'opus_usage_pct': usage_pct,
    'model_usage_all': {
        model: {
            'input': v.get('inputTokens', 0),
            'output': v.get('outputTokens', 0),
            'cache_read': v.get('cacheReadInputTokens', 0)
        }
        for model, v in d.get('modelUsage', {}).items()
    }
}

data = json.dumps(payload).encode()
req = urllib.request.Request(N8N_ENDPOINT, data=data, headers={'Content-Type': 'application/json'})
try:
    with urllib.request.urlopen(req, timeout=5) as res:
        pass
    print(f"Usage synced: {sum(month_total.values()):,} tokens this month")
except Exception as e:
    print(f"Sync failed: {e}", file=__import__('sys').stderr)
EOF
