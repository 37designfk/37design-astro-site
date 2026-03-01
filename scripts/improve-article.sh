#!/bin/bash
# 既存記事のリライト
# 使い方: ./scripts/improve-article.sh <slug> <keyword> <focus>

SLUG="${1}"
KEYWORD="${2:-}",
FOCUS="${3:-タイトル改善・meta改善・本文充実}"
SITE_DIR="/home/ken/37design-astro-site"
ARTICLE_FILE="${SITE_DIR}/src/content/blog/${SLUG}.md"
TODAY=$(date +%Y-%m-%d)

if [ ! -f "$ARTICLE_FILE" ]; then
  echo "エラー: 記事が見つかりません: $ARTICLE_FILE"
  exit 1
fi

EXISTING=$(cat "$ARTICLE_FILE")
ANALYTICS=$(cat "${SITE_DIR}/.analytics-cache.json" 2>/dev/null || echo '{}')

echo "リライト中: ${SLUG} (キーワード: ${KEYWORD})"

env -u CLAUDECODE PATH="$HOME/.local/bin:$PATH" claude -p "
あなたは37Design（株式会社37Design）のブログ記事ライターです。
代表は古田 健（ふるた けん）です。

以下の既存記事をリライトして、検索順位とCTRを改善してください。

## 改善指示
狙うキーワード: ${KEYWORD}
改善ポイント: ${FOCUS}
リライト日: ${TODAY}

## 既存記事
${EXISTING}

## Search Consoleデータ（参考）
$(echo "$ANALYTICS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
gsc = d.get('gsc', {})
queries = gsc.get('top_queries', [])
slug_pages = [p for p in gsc.get('top_pages', []) if '${SLUG}' in p.get('page', '')]
print('キーワード別データ:', json.dumps(queries[:5], ensure_ascii=False))
print('このページのデータ:', json.dumps(slug_pages, ensure_ascii=False))
" 2>/dev/null || echo 'データなし')

## リライト要件
- 既存の記事構成・トーンを活かしながら改善
- targetKeyword を h1・導入・見出しに自然に含める
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
" | node "${SITE_DIR}/scripts/save-article.js" "$TODAY" "$SLUG"
