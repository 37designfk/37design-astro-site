#!/bin/bash
# 使い方: ./scripts/generate-article.sh "AIセールス"

THEME="${1:-AIセールス}"
TODAY=$(date +%Y-%m-%d)
BLOG_DIR="$(dirname "$0")/../src/content/blog"

echo "記事生成中: ${THEME}..."

env -u CLAUDECODE PATH="$HOME/.local/bin:$PATH" claude -p "
あなたは37Design（株式会社37Design）のブログ記事ライターです。
代表は古田 健（ふるた けん）です。

以下のテーマでブログ記事を書いて、JSONで返してください。

テーマ: ${THEME}
公開日: ${TODAY}

## 記事の要件
- 文字数: 3000〜5000字
- h2を5〜7個、各h2にh3を2〜3個
- 導入 → 問題深掘り → 解決策 → CTA → まとめ の構成
- 「こんにちは、37Design代表の古田です。」で書き始める
- 禁止表現: 絶対に/確実に/100%/必ず治る/業界No.1

## カテゴリールール
- AI顧問 → category: \"AI\"
- AIセールス → category: \"業務自動化\"
- AIマーケティング → category: \"マーケティング\"

## 返却フォーマット（JSON のみ。説明文不要）
{
  \"title\": \"記事タイトル\",
  \"description\": \"120〜160字のmeta description\",
  \"slug\": \"英数字とハイフンのみ\",
  \"category\": \"カテゴリー\",
  \"tags\": [\"タグ1\", \"タグ2\", \"タグ3\"],
  \"targetKeyword\": \"メインキーワード\",
  \"body\": \"Markdown本文（frontmatterなし）\"
}
" | node "$(dirname "$0")/save-article.js" "$TODAY"
