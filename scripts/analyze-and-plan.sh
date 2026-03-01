#!/bin/bash
# GA4+GSC+記事一覧をClaudeに渡して今日のタスクを決定する
# 出力: /tmp/daily-tasks.json

SITE_DIR="/home/ken/37design-astro-site"
ANALYTICS_FILE="${SITE_DIR}/.analytics-cache.json"
OUTPUT="/tmp/daily-tasks-$$.json"
TODAY=$(date +%Y-%m-%d)

# アナリティクスデータ読み込み
if [ ! -f "$ANALYTICS_FILE" ]; then
  echo "アナリティクスデータなし。先にfetch-analytics.pyを実行してください。"
  exit 1
fi

ANALYTICS=$(cat "$ANALYTICS_FILE")

# 既存記事スラッグ一覧
SLUGS=$(ls "${SITE_DIR}/src/content/blog/" 2>/dev/null | sed 's/\.md$//' | tr '\n' ',' | sed 's/,$//')

echo "=== アナリティクス分析・タスク計画中 ==="

env -u CLAUDECODE PATH="$HOME/.local/bin:$PATH" claude -p "
あなたは37Design（中小企業向けAI・マーケティング支援）のSEOストラテジストです。

## 本日のデータ
公開日: ${TODAY}

## GA4 + Search Console データ
${ANALYTICS}

## 既存記事スラッグ一覧
${SLUGS}

## タスク決定ルール
以下の優先順でタスクを選んでください（合計3タスクまで）:

1. **rewrite（リライト）優先**:
   - GSC: position 11〜25 かつ impressions >= 50 → 1ページ目に押し上げ可能
   - GSC: impressions >= 100 かつ ctr < 3% → タイトル・metaを改善
   - GA4: top_pagesに入っていて、GSCでのランクが低い
   - slug が既存記事一覧に存在するもののみ選択

2. **new_article（新規記事）**:
   - GSCキーワードで clicks=0 かつ impressions >= 30 → 記事がない
   - データにはなくても37Design読者が検索しそうな「AI×中小企業」隣接テーマ

## 返却フォーマット（JSONのみ、説明不要）
{
  "analysis_date": "${TODAY}",
  "summary": "50字以内の状況サマリー",
  "tasks": [
    {
      "action": "rewrite",
      "slug": "既存記事のスラッグ（.mdなし）",
      "target_keyword": "狙うキーワード",
      "focus": "改善ポイント（タイトル改善/meta改善/本文追記/構成改善）",
      "reason": "なぜこの記事を選んだか（数値根拠を含む）"
    },
    {
      "action": "new_article",
      "keyword": "狙うキーワード",
      "theme": "記事テーマ",
      "reason": "なぜこのテーマが必要か"
    }
  ]
}
" > "$OUTPUT"

# JSONを抽出
JSON=$(python3 -c "
import sys, re, json
content = open('$OUTPUT').read()
match = re.search(r'\{[\\s\\S]*\}', content)
if match:
    try:
        obj = json.loads(match.group())
        print(json.dumps(obj, ensure_ascii=False))
    except: print(match.group())
" 2>/dev/null)

if [ -z "$JSON" ]; then
  echo "エラー: Claudeの出力をパースできませんでした"
  cat "$OUTPUT"
  rm -f "$OUTPUT"
  exit 1
fi

echo "$JSON" > /tmp/daily-tasks.json
rm -f "$OUTPUT"

echo "タスク計画完了:"
echo "$JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('  サマリー:', d.get('summary',''))
for i, t in enumerate(d.get('tasks', [])):
    print(f'  [{i+1}] {t[\"action\"]}: {t.get(\"slug\", t.get(\"keyword\",\"-\"))} - {t.get(\"reason\",\"\")[:60]}')
"
