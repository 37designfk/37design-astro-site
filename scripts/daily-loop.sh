#!/bin/bash
# 37Design Daily Loop - 1日2タスク版
# GA4/GSC取得 → Claude分析(2タスク) → Claude記事生成×2 → ビルド → デプロイ
# n8n: SSH 1コマンドで呼ぶだけ

set -uo pipefail
export TZ=Asia/Tokyo

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
if [ -z "$SLUG_LIST" ]; then
  SLUG_COUNT=0
else
  SLUG_COUNT=$(echo "$SLUG_LIST" | tr ',' '\n' | wc -l | tr -d ' ')
fi

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

# オーナーメモ取得（PostgreSQL）
OWNER_MEMO=$(docker exec postgres-37design psql \
  -U n8n_37design -d n8n_37design -t -A \
  -c "SELECT COALESCE(content,'') FROM owner_memo WHERE id=1" 2>/dev/null || echo "")
if [ -n "$OWNER_MEMO" ]; then
  log "オーナーメモ取得: ${#OWNER_MEMO}字"
else
  log "オーナーメモ: なし（またはPostgreSQL接続失敗）"
fi

# ============================================
# Step 2: Claude 1回目 — サイト分析 → 2タスク選定
# ============================================
log "Claude分析中（2タスク選定）..."

if [ "$REWRITE_ONLY" = "true" ]; then
  TASK_INSTRUCTION="rewrite（リライト）を2つ選んでください。新規記事は禁止です。
ロック中のスラッグは選ばないこと。ロック外でリライト対象がなければ1つだけでも構いません。

【最優先で選ぶべき記事】
GSC で「Imp 100以上 かつ CTR 1.0%未満 かつ 順位5-15位」の記事をまずチェック。
1ページ目下端〜2ページ目で表示されているのにクリックされない＝title/descriptionが弱い。
次に「Imp 50以上 かつ 順位16-30位」の記事（順位押し上げ余地あり）。"
  TASK_FORMAT='"rewrite"'
else
  TASK_INSTRUCTION="以下の2タスクを選んでください:

【選定の優先順位】
1. **CTR改善rewrite（最優先）**: GSC で Imp 100以上・CTR 1.0%未満・順位5-15位 の記事。
   1ページ目で表示されているのにクリックされていない記事のtitle/descriptionを再設計してCTRを引き上げる。
2. **順位押し上げrewrite**: 順位16-30位で Imp 50以上 の記事。本文厚みやFAQ追加で1ページ目入りを狙う。
3. **new_article（新規記事）**: 上記の rewrite 候補が枯渇した場合のみ。

1つ目: 上記の優先順位に従って選定（**rewrite を強く優先**）
2つ目: 上記の優先順位に従って選定（**rewrite を強く優先**。同一クラスタの記事を続けて触ると内部リンク強化と相性が良い）

ロック中のスラッグは選ばないこと。"
  TASK_FORMAT='"rewrite" or "new_article"'
fi

# ============================================
# 集約方針（メッセージ統一）— 全タスク共通の編集ルール
# ============================================
AGGREGATION_POLICY='【全記事共通の集約方針：すべての記事はAI顧問サービスへの導線として書く】

37Designの主商品は **「AI顧問サービス（月額2万円〜）」**。すべてのブログ記事は最終的に AI顧問契約への流入を目的として書く。

必ず守ること:
1. **本文中で1回以上「AI顧問」という言葉を使う**（ブランド検索強化）。
2. **記事末尾の独自CTAブロックは置かない**（[slug].astroの共通CTAがAI顧問LPに集約済み）。本文末尾は「まとめ」で締めて、独自の「お問い合わせはこちら」セクションは追加しない。
3. **本文中の文中リンクは AI顧問関連の柱記事 or `/lp/ai-consulting/` に集約**:
   - 柱記事候補: `ai-advisor-complete-guide` / `ai-advisor-fee-comparison-2026` / `ai-advisor-vs-consultant-sme` / `ai-advisor-success-cases-by-industry`
   - LP: `/lp/ai-consulting/`（料金確認・申込み導線）/ `/lp/ai-assessment/`（無料診断）
4. **記事のフレーミング**: 「業務自動化したい」「補助金使いたい」「請求書効率化したい」等の課題系記事も、最終的に「= AI顧問に伴走してもらうのが最短」と接続する。
5. **targetLP frontmatter は `/lp/ai-consulting` を基本値にする**（特別な理由があるときのみ変更）。
6. 既存記事のリライト時も、上記方針に沿って文中リンク・トーンを調整する。'

# ============================================
# E-E-A-T 強化方針（Scaled Content Abuse対策）
# Google Quality Rater Guidelines準拠。AI生成のテンプレ感を消すための必須要件。
# ============================================
EEAT_POLICY='【E-E-A-T 必須要件：AI生成テンプレ感を消すために絶対に守ること】

Google は2024年3月のSpam Update以降、「Scaled Content Abuse（量産による低価値コンテンツ）」を手動措置の対象としている。
ペナルティを受けたAIサイトの共通点は (1)著者エンティティなし (2)独自データなし (3)テンプレ統一すぎ の3つ。本記事は以下を全て満たすこと:

1. **一次経験の挿入（Experience）**: 必ず本文中に1箇所以上、以下のいずれかを含める:
   - 古田が支援した中小企業の具体事例（業種・規模・課題・成果数値）。架空の事例でも可だが、必ず数字と背景を具体的に書く（例「製造業・従業員25名・営業の見積書作成に月90時間かかっていたのが12時間に削減」）
   - 古田が運用する14プロダクト（Lexion Hub Sales/HYDRA/Voistia/AI Tools Media等）からの一次的気づき
   - 「2026年4月時点で実際にこのツールを試したところ…」という現場での検証ログ
   実体のないコピペ的な「導入事例」「成功事例」と書くだけは禁止。読者が「これは本当に使った人が書いている」と感じる粒度の数値・固有名詞を入れること。

2. **「私（古田）」「弊社」一人称の混在**: 解説調だけでなく、適度に「私が見てきた限り」「弊社のクライアントでは」という主観・視点を混ぜる。AI記事はこれが欠落しがち。

3. **構造の多様化（テンプレ感排除）**: ARTICLE_TYPE 指示に従い、毎回同じH2構造を作らない。

4. **断定・煽りを避ける**: 「絶対」「100%」「必ず」「業界No.1」等は禁止表現として既に指定済み。AI過剰最適化された文章は人間レビュアーから減点される。

5. **frontmatter author は必ず「古田 健」**（Person schemaと一貫させるため）。'

# ============================================
# 記事タイプの多様化（テンプレ感排除）
# ============================================
# new_article時にランダム選択。最近5本との重複を避けるため、ファイル更新日時から推定
ARTICLE_TYPES=("explainer" "case_study" "comparison" "qa_format" "how_to_steps")
# 直近5本のスラッグから type 推定（簡易）
RECENT_TYPES=$(ls -t "$SITE_DIR/src/content/blog/"*.md 2>/dev/null | head -5 | xargs -n1 basename | sed 's/\.md$//')
ARTICLE_TYPE_INDEX=$(($(date +%s) % 5))
ARTICLE_TYPE="${ARTICLE_TYPES[$ARTICLE_TYPE_INDEX]}"
case "$ARTICLE_TYPE" in
  explainer)
    ARTICLE_TYPE_SPEC='**explainer型（解説型）**: H2は「○○とは / なぜ重要か / 仕組み / 使い方 / 注意点 / まとめ」。読者は概念を理解したい初学者。' ;;
  case_study)
    ARTICLE_TYPE_SPEC='**case_study型（事例型）**: H2は「導入前の課題 / 検討したアプローチ / 採用した解決策 / 実装ステップ / 数値で見た効果 / 失敗ポイントと対策 / 横展開のヒント」。架空でも具体数字・業種・規模を盛り込む。' ;;
  comparison)
    ARTICLE_TYPE_SPEC='**comparison型（比較型）**: H2は「比較対象の選定基準 / 各候補の長所短所 / こんな企業にはコレ / 選び方のチェックリスト / 弊社の推奨」。比較表（Markdown table）必須。' ;;
  qa_format)
    ARTICLE_TYPE_SPEC='**qa_format型（Q&A型）**: H2 は質問形式（「○○は本当に効果ある？」「△△と□□の違いは？」等）を5-7個。各回答に短い結論→根拠→補足の三段。FAQPage schemaのfrontmatter `faqs` 配列も埋める。' ;;
  how_to_steps)
    ARTICLE_TYPE_SPEC='**how_to_steps型（手順型）**: H2は「準備すること / STEP1〜STEP5 / つまずきやすいポイント / 完成後のチェックリスト」。各STEPは独立して実行可能な粒度に分解。' ;;
esac


cat > /tmp/daily-loop-analyze.$$ << ANALYZE_EOF
あなたは37Design（**AI顧問サービス**を主商品とする中小企業向けAI支援会社）のSEOストラテジストです。

${AGGREGATION_POLICY}

${EEAT_POLICY}

---

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

## オーナーからのメモ・方針（最優先で考慮すること）
${OWNER_MEMO:-（メモなし）}

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
あなたは37Design（**AI顧問サービス**を主商品とする中小企業向けAI支援会社）のブログ記事ライターです。
代表は古田 健（ふるた けん）です。

${AGGREGATION_POLICY}

${EEAT_POLICY}

---

以下の既存記事をリライトして、検索順位とCTRを改善してください。

## 改善指示
狙うキーワード: ${KEYWORD}
改善ポイント: タイトル改善・meta改善・本文充実・内部リンク追加・**AI顧問への集約強化**
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
- 内部リンクを3本以上含める（/blog/スラッグ/ 形式）。**1本以上は AI顧問柱記事 (ai-advisor-*) に向ける**
- 本文中で「AI顧問」を最低1回は使う
- 記事末尾の独自CTAブロック（contact等への誘導セクション）は削除する。共通CTAが [slug].astro 側にある
- タイトルはクリックされやすく（数字・メリット・疑問形を活用）
- meta descriptionは120〜160字でクリックを促す文章
- frontmatterに `targetLP: "/lp/ai-consulting"` を必ず含める
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
あなたは37Design（**AI顧問サービス**を主商品とする中小企業向けAI支援会社）のブログ記事ライターです。
代表は古田 健（ふるた けん）です。

${AGGREGATION_POLICY}

${EEAT_POLICY}

---

## 今回採用する記事フォーマット
${ARTICLE_TYPE_SPEC}

---

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
- 構成: 導入 → 問題深掘り → 解決策 → **AI顧問への接続** → まとめ
- 「こんにちは、37Design代表の古田です。」で書き始める
- targetKeywordをh1・導入文・見出しに自然に含める
- 内部リンクを3本以上含める（/blog/スラッグ/ 形式）。**1本以上は AI顧問柱記事 (ai-advisor-*) に向ける**
- 本文中で「AI顧問」を最低1回は使い、「= AI顧問に伴走してもらうのが最短」のフレーミングで終盤を書く
- 記事末尾の独自CTAブロック（contact等への誘導セクション）は書かない。共通CTAが [slug].astro 側にあるので、本文末は「まとめ」で締める
- frontmatterに `targetLP: "/lp/ai-consulting"` を必ず含める
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
