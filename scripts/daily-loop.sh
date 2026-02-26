#!/bin/bash
# 37Design Daily Loop - 1日2タスク版
# GA4/GSC取得 → Claude分析(2タスク) → Claude記事生成×2 → ビルド → デプロイ
# n8n: SSH 1コマンドで呼ぶだけ

set -uo pipefail

SITE_DIR="/home/ken/37design-astro-site"
LOCK_FILE="$SITE_DIR/.article-lock.json"
ANALYTICS_FILE="$SITE_DIR/.analytics-cache.json"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
TODAY=$(date +%Y-%m-%d)
LOCK_DAYS=7
CLAUDE="env -u CLAUDECODE PATH=$HOME/.local/bin:$PATH claude -p"

cd "$SITE_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

notify() {
  [ -z "$DISCORD_WEBHOOK" ] && return 0
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
python3 "$SITE_DIR/scripts/fetch-analytics.py" > /dev/null 2>&1 || log "WARN: Analytics取得スクリプトが非ゼロ終了"
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
  LOCKED_SLUGS=$(LOCK_FILE="$LOCK_FILE" LOCK_DAYS="$LOCK_DAYS" python3 -c "
import json, os
from datetime import datetime, timedelta
try:
    locks = json.load(open(os.environ['LOCK_FILE']))
    cutoff = datetime.now() - timedelta(days=int(os.environ['LOCK_DAYS']))
    print(','.join(k for k,v in locks.items() if datetime.fromisoformat(v) > cutoff))
except: pass
" 2>/dev/null)
fi
log "既存記事: ${SLUG_COUNT}本 / ロック中: ${LOCKED_SLUGS:-なし}"

# ============================================
# ブレーキ: 記事数上限チェック
# ============================================
MAX_ARTICLES=50
REWRITE_ONLY="false"
if [ "$SLUG_COUNT" -ge "$MAX_ARTICLES" ]; then
  REWRITE_ONLY="true"
  log "ブレーキ: 記事数 ${SLUG_COUNT}本 (上限${MAX_ARTICLES}) → リライトのみモード"
  notify "ブレーキ発動: 記事${SLUG_COUNT}本で上限到達。リライトのみモード。" 16776960
fi

# ============================================
# カニバリ検知: GSCで同一キーワードに複数記事
# ============================================
CANNIBALIZATION=$(ANALYTICS_FILE="$ANALYTICS_FILE" python3 -c "
import json, os
try:
    d = json.load(open(os.environ['ANALYTICS_FILE']))
    pages = d.get('gsc', {}).get('top_pages', [])
    blog_pages = [p for p in pages if '/blog/' in p.get('page', '')]
    if len(blog_pages) >= 2:
        close_pages = [p for p in blog_pages if p.get('position', 100) <= 20]
        if len(close_pages) >= 2:
            slugs = [p['page'].rstrip('/').split('/')[-1] for p in close_pages]
            print(','.join(slugs))
except: pass
" 2>/dev/null)

if [ -n "$CANNIBALIZATION" ]; then
  log "カニバリ警告: ${CANNIBALIZATION}"
  notify "⚠️ カニバリ検知: ${CANNIBALIZATION}\n同一キーワード圏内に複数記事。統合またはnoindex検討。" 16776960
fi

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
# Step 2: Claude 1回目 — サイト分析 → 2タスク選定
# ============================================
log "Claude分析中（2タスク選定）..."

if [ "$REWRITE_ONLY" = "true" ]; then
  TASK_INSTRUCTION="rewrite（リライト）を2つ選んでください。新規記事は禁止です。
ロック中のスラッグは選ばないこと。ロック外でリライト対象がなければ1つだけでも構いません。"
  TASK_FORMAT='"rewrite"'
else
  TASK_INSTRUCTION="以下の2タスクを選んでください:
1つ目: **rewrite（リライト）** — GA4でPVがあるのにGSCで順位が低い既存記事。CTR改善余地がある記事。ロック中は選べません。ロック外に良い候補がなければnew_articleで代替可。
2つ目: **new_article（新規記事）** — 既存記事でカバーしていない「AI×中小企業」関連テーマ。検索需要が見込めるもの。"
  TASK_FORMAT='"rewrite" or "new_article"'
fi

cat > /tmp/daily-loop-analyze.$$ << ANALYZE_EOF
あなたは37Design（中小企業向けAI・マーケティング支援）のSEOストラテジストです。
${TASK_INSTRUCTION}

## サイトマップ（公開中の全URL）
${SITEMAP}

## GA4 + Search Console データ
$(cat "$ANALYTICS_FILE")

## 既存記事スラッグ一覧（.mdファイル）
${SLUG_LIST}

## ロック中（更新不可。選ばないこと）
${LOCKED_SLUGS:-なし}

## 現在の記事数
${SLUG_COUNT}本 / 上限${MAX_ARTICLES}本

## カニバリ警告
$([ -n "$CANNIBALIZATION" ] && echo "以下の記事がGSC上位20位内で競合中: ${CANNIBALIZATION}" || echo "なし")

## 返却（JSON配列のみ、説明不要）
[
  {
    "action": ${TASK_FORMAT},
    "slug": "対象スラッグ（新規の場合は新しいスラッグ）",
    "target_keyword": "狙うキーワード",
    "reason": "選定理由（数値根拠含む、80字以内）"
  },
  { ... 2つ目 ... }
]
ANALYZE_EOF

if ! $CLAUDE < /tmp/daily-loop-analyze.$$ > /tmp/daily-loop-plan.$$ 2>/dev/null; then
  log "WARN: Claude分析で非ゼロ終了（応答は取得済みの場合あり）"
fi

# JSON配列をパース
TASKS=$(python3 -c "
import json, sys
raw = open('/tmp/daily-loop-plan.$$').read()
# []で囲まれた最大のブロックを探す
matches = []
depth = 0; start = -1
for i, c in enumerate(raw):
    if c == '[':
        if depth == 0: start = i
        depth += 1
    elif c == ']':
        depth -= 1
        if depth == 0 and start >= 0:
            matches.append(raw[start:i+1]); start = -1
if not matches:
    # 配列がなければ{}オブジェクトを1つ探してラップ
    depth = 0; start = -1; objs = []
    for i, c in enumerate(raw):
        if c == '{':
            if depth == 0: start = i
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0 and start >= 0:
                objs.append(raw[start:i+1]); start = -1
    if objs:
        matches = ['[' + ','.join(objs[:2]) + ']']
if not matches:
    print('[]'); sys.exit(0)
arr = json.loads(sorted(matches, key=len, reverse=True)[0])
if not isinstance(arr, list): arr = [arr]
print(json.dumps(arr[:2], ensure_ascii=False))
" 2>/dev/null)

if [ -z "$TASKS" ] || [ "$TASKS" = "[]" ]; then
  log "ERROR: 分析結果のパース失敗"
  notify "❌ 分析結果パース失敗" 16711680
  exit 1
fi

TASK_COUNT=$(echo "$TASKS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
log "分析完了: ${TASK_COUNT}タスク"

# ============================================
# Step 3: タスクループ — 各タスクを生成・保存
# ============================================
SUCCESS_COUNT=0
SUMMARY=""

git config user.name "37Design Marketing OS"
git config user.email "os@37d.jp"

for i in $(seq 0 $((TASK_COUNT - 1))); do
  ACTION=$(echo "$TASKS" | python3 -c "import json,sys; print(json.load(sys.stdin)[$i]['action'])")
  SLUG=$(echo "$TASKS" | python3 -c "import json,sys; print(json.load(sys.stdin)[$i]['slug'])")
  KEYWORD=$(echo "$TASKS" | python3 -c "import json,sys; print(json.load(sys.stdin)[$i]['target_keyword'])")
  REASON=$(echo "$TASKS" | python3 -c "import json,sys; print(json.load(sys.stdin)[$i]['reason'])")

  log "--- タスク$((i+1))/${TASK_COUNT}: ${ACTION} → ${SLUG} (${KEYWORD}) ---"
  log "理由: ${REASON}"

  # ロックチェック（リライト対象）
  if [ "$ACTION" = "rewrite" ]; then
    IS_LOCKED=$(LOCKED_SLUGS="$LOCKED_SLUGS" SLUG="$SLUG" python3 -c "
import os
locked = os.environ.get('LOCKED_SLUGS','').split(',')
print('yes' if os.environ.get('SLUG','') in locked else 'no')
" 2>/dev/null)
    if [ "$IS_LOCKED" = "yes" ]; then
      log "スキップ: ${SLUG} はロック中"
      continue
    fi
    if [ ! -f "$SITE_DIR/src/content/blog/${SLUG}.md" ]; then
      log "スキップ: ${SLUG}.md が存在しない"
      continue
    fi
  fi

  # --- 記事生成 ---
  log "Claude記事生成中 (${ACTION}: ${SLUG})..."

  if [ "$ACTION" = "rewrite" ]; then
    ARTICLE_FILE="$SITE_DIR/src/content/blog/${SLUG}.md"

    GSC_DATA=$(ANALYTICS_FILE="$ANALYTICS_FILE" SLUG="$SLUG" python3 -c "
import json, os
d = json.load(open(os.environ['ANALYTICS_FILE']))
queries = d.get('gsc',{}).get('top_queries',[])[:5]
slug = os.environ.get('SLUG','')
pages = [p for p in d.get('gsc',{}).get('top_pages',[]) if slug in p.get('page','')]
print('キーワード:', json.dumps(queries, ensure_ascii=False))
print('ページ:', json.dumps(pages, ensure_ascii=False))
" 2>/dev/null || echo "データなし")

    cat > /tmp/daily-loop-generate-${i}.$$ << REWRITE_EOF
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
    cat > /tmp/daily-loop-generate-${i}.$$ << NEW_EOF
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

  if ! $CLAUDE < /tmp/daily-loop-generate-${i}.$$ > /tmp/daily-loop-article-${i}.$$ 2>/dev/null; then
    log "WARN: Claude生成で非ゼロ終了（応答は取得済みの場合あり）"
  fi

  if [ ! -s /tmp/daily-loop-article-${i}.$$ ]; then
    log "WARN: Claude応答なし (${SLUG}) → スキップ"
    continue
  fi

  # --- 保存 ---
  SAVE_OUTPUT=$(cat /tmp/daily-loop-article-${i}.$$ | node "$SITE_DIR/scripts/save-article.js" "$TODAY" 2>&1) || true

  if echo "$SAVE_OUTPUT" | grep -q "保存完了"; then
    log "$SAVE_OUTPUT"
  else
    log "WARN: 記事保存失敗 (${SLUG}): $SAVE_OUTPUT → スキップ"
    continue
  fi

  # --- ロック設定 ---
  LOCK_FILE="$LOCK_FILE" SLUG="$SLUG" python3 -c "
import json, os
from datetime import datetime
f = os.environ['LOCK_FILE']
try: locks = json.load(open(f))
except: locks = {}
locks[os.environ['SLUG']] = datetime.now().isoformat()
json.dump(locks, open(f, 'w'), indent=2)
" 2>/dev/null
  log "ロック設定: ${SLUG} (${LOCK_DAYS}日間)"

  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  SUMMARY="${SUMMARY}${ACTION}: ${SLUG} (${KEYWORD})\n"

  # タスクログ送信
  curl -s -X POST "https://n8n-onprem.37d.jp/webhook/37design-log-task" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"blog_generate\",\"title\":\"${ACTION}: ${SLUG}\",\"slug\":\"$SLUG\",\"status\":\"done\",\"priority\":\"medium\"}" \
    > /dev/null 2>&1 || true
done

# ============================================
# Step 4: コミット → ビルド → デプロイ
# ============================================
if [ "$SUCCESS_COUNT" -eq 0 ]; then
  log "タスク成功なし。ビルドスキップ。"
  notify "⚠️ Daily Loop: 全タスクスキップ（ロック中 or 生成失敗）" 16776960
  exit 0
fi

git add -A src/content/blog/ .article-lock.json
git commit -m "daily: ${SUCCESS_COUNT}タスク完了 (${TODAY})" -q 2>/dev/null || true

log "ビルド中..."
if ! npm run build > /dev/null 2>&1; then
  log "ERROR: ビルド失敗"
  notify "❌ ビルド失敗" 16711680
  exit 1
fi
log "ビルド成功"

log "Git push中..."
git push origin main -q 2>/dev/null || log "WARN: git push失敗（後で手動push必要）"

log "デプロイ中..."
XSERVER_USER="server37"
XSERVER_HOST="sv2023.xserver.jp"
XSERVER_PORT="10022"
XSERVER_KEY="$HOME/.ssh/server37.key"
XSERVER_PATH="~/37design.co.jp/public_html/"

rsync -avz --delete \
  -e "ssh -i $XSERVER_KEY -p $XSERVER_PORT -o StrictHostKeyChecking=accept-new" \
  "$SITE_DIR/dist/" \
  "$XSERVER_USER@$XSERVER_HOST:$XSERVER_PATH" > /dev/null 2>&1 \
  || log "WARN: rsyncデプロイ失敗"
log "デプロイ完了"

# ============================================
# Step 5: 通知
# ============================================
notify "✅ Daily Loop完了 (${SUCCESS_COUNT}タスク)\n${SUMMARY}" 3066993

log "=== Daily Loop 完了 (${SUCCESS_COUNT}タスク) ==="
