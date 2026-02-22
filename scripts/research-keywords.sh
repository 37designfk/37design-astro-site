#!/bin/bash
# キーワード深掘りスクリプト
# 使い方: ./scripts/research-keywords.sh "AIセールス"

THEME="${1:-AIセールス}"

echo "「${THEME}」のキーワード調査中..."

env -u CLAUDECODE claude -p "
あなたはSEOコンサルタントです。
37Design（中小企業向けAI・マーケティング支援会社）のブログ記事を計画しています。

テーマ「${THEME}」について、以下をJSONで返してください。

{
  \"theme\": \"テーマ名\",
  \"main_keywords\": [
    {
      \"keyword\": \"キーワード\",
      \"intent\": \"情報収集 | 比較検討 | 購買意欲\",
      \"difficulty\": \"低 | 中 | 高\",
      \"priority\": \"高 | 中 | 低\"
    }
  ],
  \"long_tail_keywords\": [\"ロングテールキーワード\"],
  \"article_ideas\": [
    {
      \"title\": \"記事タイトル案\",
      \"keyword\": \"狙うキーワード\",
      \"angle\": \"差別化の切り口\",
      \"target\": \"ターゲット読者\"
    }
  ],
  \"content_cluster\": {
    \"pillar\": \"ピラーページのタイトル案\",
    \"cluster_articles\": [\"クラスター記事タイトル1\", \"クラスター記事タイトル2\"]
  }
}

条件:
- main_keywordsは10個
- long_tail_keywordsは15個
- article_ideasは5個
- 中小企業の経営者・マーケター向けを意識
- JSONのみ返す（説明文不要）
"
