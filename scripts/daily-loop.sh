#!/bin/bash
# 37Design Daily Loop - シンプル版
# GA4/GSC取得 → Claude分析 → Claude記事生成 → ビルド → デプロイ
# n8n: SSH 1コマンドで呼ぶだけ

set -euo pipefail

SITE_DIR="/home/ken/37design-astro-site"
LOCK_FILE="$SITE_DIR/.article-lock.json"
ANALYTICS_FILE="$SITE_DIR/.analytics-cache.json"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1475966863417802805/hrIPYPVKwZ2nP1ob8cq7c0W2O9tc-BZPFT6HELCnxt8mRX4N65kOPg__G0_YvDUFdZBG"
TODAY=$(date +%Y-%m-%d)
LOCK_DAYS=7
CLAUDE="env -u CLAUDECODE PATH=$HOME/.local/bin:$PATH claude -p"

cd "$SITE_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

notify() {
  local msg="$1" color="${2:-3447003}"
  curl -s -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"embeds\":[{\"title\":\"Daily Loop\",\"description\":\"$msg\",\"color\":$color,\"timestamp\":\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"}]}" \
    > /dev/null 2>&1 || true
}

cleanup() { rm -f /tmp/daily-loop-*.$$; }
trap cleanup EXIT

# ============================================
# Step 1: 準備
# ============================================
log "Git pull..."
git pull origin main -q 2>/dev/null || true

log "Analytics取得中..."
python3 "$SITE_DIR/scripts/fetch-analytics.py" > /dev/null 2>&1
if [ ! -f "$ANALYTICS_FILE" ]; then
  log "ERROR: Analytics取得失敗"
  notify "❌ Analytics取得失敗" 16711680
  exit 1
fi
log "Analytics取得完了"

# 既存記事一覧
SLUG_LIST=$(ls "$SITE_DIR/src/content/blog/"*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//' | sort | tr '\n' ',' | sed 's/,$//')
SLUG_COUNT=$(echo "$SLUG_LIST" | tr ',' '\n' | wc -l | tr -d ' ')

# ロック済み記事
LOCKED_SLUGS=""
if [ -f "$LOCK_FILE" ]; then
  LOCKED_SLUGS=$(python3 -c "
import json
from datetime import datetime, timedelta
try:
    locks = json.load(open('$LOCK_FILE'))
    cutoff = datetime.now() - timedelta(days=$LOCK_DAYS)
    print(','.join(k for k,v in locks.items() if datetime.fromisoformat(v) > cutoff))
except: pass
" 2>/dev/null)
fi
log "既存記事: ${SLUG_COUNT}本 / ロック中: ${LOCKED_SLUGS:-なし}"

# サイトマップ取得（公開中の全URL）
log "サイトマップ取得中..."
SITEMAP=$(curl -s https://37design.co.jp/sitemap-0.xml 2>/dev/null \
  | python3 -c "
import sys, re
raw = sys.stdin.read()
urls = re.findall(r'<loc>([^<]+)</loc>', raw)
for u in urls:
    print(u)
" 2>/dev/null || echo "取得失敗")
SITEMAP_COUNT=$(echo "$SITEMAP" | wc -l | tr -d ' ')
log "サイトマップ: ${SITEMAP_COUNT} URL"

# ============================================
# Step 2: Claude 1回目 — サイト分析 → タスク判断
# ============================================
log "Claude分析中..."

cat > /tmp/daily-loop-analyze.$$ << ANALYZE_EOF
あなたは37Design（中小企業向けAI・マーケティング支援）のSEOストラテジストです。
サイトの成長に最も効果的な施策を1つ選んでください。

## サイトマップ（公開中の全URL）
${SITEMAP}

## GA4 + Search Console データ
$(cat "$ANALYTICS_FILE")

## 既存記事スラッグ一覧（.mdファイル）
${SLUG_LIST}

## ロック中（更新不可。選ばないこと）
${LOCKED_SLUGS:-なし}

## 判断基準
1. **rewrite（リライト）**: GA4でPVがあるのにGSCで順位が低い既存記事。CTR改善余地がある記事。
2. **new_article（新規記事）**: 既存記事でカバーしていない「AI×中小企業」関連テーマ。検索需要が見込めるもの。

## 返却（JSONのみ、説明不要）
{
  "action": "rewrite" or "new_article",
  "slug": "対象スラッグ（新規の場合は新しいスラッグ）",
  "target_keyword": "狙うキーワード",
  "reason": "選定理由（数値根拠含む、80字以内）"
}
ANALYZE_EOF

$CLAUDE < /tmp/daily-loop-analyze.$$ > /tmp/daily-loop-plan.$$ 2>/dev/null

# JSONをパース
PLAN=$(python3 -c "
import json, re, sys
raw = open('/tmp/daily-loop-plan.$$').read()
matches = []
depth = 0; start = -1
for i, c in enumerate(raw):
    if c == '{':
        if depth == 0: start = i
        depth += 1
    elif c == '}':
        depth -= 1
        if depth == 0 and start >= 0:
            matches.append(raw[start:i+1]); start = -1
if not matches:
    print('ERROR: JSONなし', file=sys.stderr); sys.exit(1)
d = json.loads(sorted(matches, key=len, reverse=True)[0])
print(json.dumps(d, ensure_ascii=False))
" 2>/dev/null)

if [ -z "$PLAN" ]; then
  log "ERROR: 分析結果のパース失敗"
  notify "❌ 分析結果パース失敗" 16711680
  exit 1
fi

ACTION=$(echo "$PLAN" | python3 -c "import json,sys; print(json.load(sys.stdin)['action'])")
SLUG=$(echo "$PLAN" | python3 -c "import json,sys; print(json.load(sys.stdin)['slug'])")
KEYWORD=$(echo "$PLAN" | python3 -c "import json,sys; print(json.load(sys.stdin)['target_keyword'])")
REASON=$(echo "$PLAN" | python3 -c "import json,sys; print(json.load(sys.stdin)['reason'])")

log "判断: ${ACTION} → ${SLUG} (${KEYWORD})"
log "理由: ${REASON}"

# ============================================
# Step 3: Claude 2回目 — 記事生成
# ============================================
log "記事生成中..."

if [ "$ACTION" = "rewrite" ]; then
  # --- リライト: 既存記事全文を渡す ---
  ARTICLE_FILE="$SITE_DIR/src/content/blog/${SLUG}.md"
  if [ ! -f "$ARTICLE_FILE" ]; then
    log "ERROR: 記事が見つかりません: ${SLUG}.md"
    notify "❌ 記事なし: ${SLUG}" 16711680
    exit 1
  fi

  # GSCデータ抽出
  GSC_DATA=$(python3 -c "
import json
d = json.load(open('$ANALYTICS_FILE'))
queries = d.get('gsc',{}).get('top_queries',[])[:5]
pages = [p for p in d.get('gsc',{}).get('top_pages',[]) if '$SLUG' in p.get('page','')]
print('キーワード:', json.dumps(queries, ensure_ascii=False))
print('ページ:', json.dumps(pages, ensure_ascii=False))
" 2>/dev/null || echo "データなし")

  cat > /tmp/daily-loop-generate.$$ << REWRITE_EOF
あなたは37Design（株式会社37Design）のブログ記事ライターです。
代表は古田 健（ふるた けん）です。

以下の既存記事をリライトして、検索順位とCTRを改善してください。

## 改善指示
狙うキーワード: ${KEYWORD}
改善ポイント: タイトル改善・meta改善・本文充実・内部リンク追加
リライト日: ${TODAY}

## 既存記事
$(cat "$ARTICLE_FILE")

## Search Consoleデータ（参考）
${GSC_DATA}

## 既存記事スラッグ一覧（内部リンク用）
${SLUG_LIST}

## リライト要件
- 既存の記事構成・トーンを活かしながら改善
- 本文3000〜5000字
- h2を5〜7個、各h2にh3を2〜3個
- 「こんにちは、37Design代表の古田です。」で書き始める
- targetKeyword を h1・導入・見出しに自然に含める
- 内部リンクを3本以上含める（/blog/スラッグ/ 形式）
- タイトルはクリックされやすく（数字・メリット・疑問形を活用）
- meta descriptionは120〜160字でクリックを促す文章
- 禁止表現: 絶対に/確実に/100%/必ず/業界No.1

## 返却フォーマット（JSONのみ、説明不要）
{
  "title": "改善後タイトル",
  "description": "改善後meta description",
  "slug": "${SLUG}",
  "category": "既存のcategoryを維持",
  "tags": ["タグ1", "タグ2", "タグ3"],
  "targetKeyword": "${KEYWORD}",
  "body": "改善後Markdown本文（frontmatterなし）"
}
REWRITE_EOF

else
  # --- 新規記事 ---
  cat > /tmp/daily-loop-generate.$$ << NEW_EOF
あなたは37Design（株式会社37Design）のブログ記事ライターです。
代表は古田 健（ふるた けん）です。

以下のテーマでブログ記事を書いて、JSONで返してください。

## テーマ
狙うキーワード: ${KEYWORD}
スラッグ: ${SLUG}
公開日: ${TODAY}

## 既存記事スラッグ一覧（内部リンク用）
${SLUG_LIST}

## 記事の要件
- 本文3000〜5000字
- h2を5〜7個、各h2にh3を2〜3個
- 導入 → 問題深掘り → 解決策 → CTA → まとめ の構成
- 「こんにちは、37Design代表の古田です。」で書き始める
- targetKeywordをh1・導入文・見出しに自然に含める
- 内部リンクを3本以上含める（/blog/スラッグ/ 形式）
- meta descriptionは120〜160字
- 禁止表現: 絶対に/確実に/100%/必ず/業界No.1

## 返却フォーマット（JSONのみ、説明不要）
{
  "title": "記事タイトル",
  "description": "meta description",
  "slug": "${SLUG}",
  "category": "AI | 業務自動化 | マーケティング | CRM | SEO",
  "tags": ["タグ1", "タグ2", "タグ3"],
  "targetKeyword": "${KEYWORD}",
  "body": "Markdown本文（frontmatterなし）"
}
NEW_EOF
fi

$CLAUDE < /tmp/daily-loop-generate.$$ > /tmp/daily-loop-article.$$ 2>/dev/null

if [ ! -s /tmp/daily-loop-article.$$ ]; then
  log "ERROR: Claude記事生成 応答なし"
  notify "❌ Claude記事生成 応答なし" 16711680
  exit 1
fi

# ============================================
# Step 4: 保存 → ロック → コミット
# ============================================
log "記事保存中..."
SAVE_OUTPUT=$(cat /tmp/daily-loop-article.$$ | node "$SITE_DIR/scripts/save-article.js" "$TODAY" 2>&1) || true

if echo "$SAVE_OUTPUT" | grep -q "保存完了"; then
  log "$SAVE_OUTPUT"
else
  log "ERROR: 記事保存失敗: $SAVE_OUTPUT"
  notify "❌ 記事保存失敗" 16711680
  exit 1
fi

# ロック設定
python3 -c "
import json
from datetime import datetime
f = '$LOCK_FILE'
try: locks = json.load(open(f))
except: locks = {}
locks['$SLUG'] = datetime.now().isoformat()
json.dump(locks, open(f, 'w'), indent=2)
" 2>/dev/null
log "ロック設定: ${SLUG} (${LOCK_DAYS}日間)"

# コミット
git add -A src/content/blog/ .article-lock.json
git config user.name "37Design Marketing OS"
git config user.email "os@37d.jp"
git commit -m "daily: ${ACTION} ${SLUG} (${TODAY})" -q 2>/dev/null || true

# ============================================
# Step 5: ビルド → デプロイ
# ============================================
log "ビルド中..."
if ! npm run build > /dev/null 2>&1; then
  log "ERROR: ビルド失敗"
  notify "❌ ビルド失敗 (${SLUG})" 16711680
  exit 1
fi
log "ビルド成功"

log "デプロイ中..."
bash "$SITE_DIR/scripts/deploy.sh" main > /dev/null 2>&1
log "デプロイ完了"

# ============================================
# Step 6: 通知
# ============================================
curl -s -X POST "https://n8n-onprem.37d.jp/webhook/37design-log-task" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"blog_generate\",\"title\":\"${ACTION}: ${SLUG}\",\"slug\":\"$SLUG\",\"status\":\"done\",\"priority\":\"medium\"}" \
  > /dev/null 2>&1 || true

notify "✅ ${ACTION}: ${SLUG}\nキーワード: ${KEYWORD}\n理由: ${REASON}" 3066993

log "=== Daily Loop 完了 ==="
