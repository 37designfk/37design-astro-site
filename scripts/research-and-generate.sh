#!/bin/bash
# キーワード調査 → 記事生成を一括実行
# 使い方: ./scripts/research-and-generate.sh "AIセールス" [記事本数]

THEME="${1:-AIセールス}"
COUNT="${2:-3}"  # 生成する記事本数（デフォルト3）
SCRIPT_DIR="$(dirname "$0")"
TMP_FILE="/tmp/research-$$.json"

echo "=== 「${THEME}」キーワード調査中... ==="

# Step1: キーワード調査
env -u CLAUDECODE claude -p "
あなたはSEOコンサルタントです。
37Design（中小企業向けAI・マーケティング支援会社）のブログ記事を計画しています。

テーマ「${THEME}」について、以下をJSONで返してください。

{
  \"theme\": \"テーマ名\",
  \"article_ideas\": [
    {
      \"title\": \"記事タイトル案\",
      \"keyword\": \"狙うキーワード\",
      \"angle\": \"差別化の切り口\"
    }
  ]
}

条件:
- article_ideasは${COUNT}個
- 中小企業の経営者・マーケター向けを意識
- 検索ボリュームが見込めるロングテールキーワードを優先
- JSONのみ返す（説明文不要）
" > "$TMP_FILE"

# JSONを抽出
JSON=$(grep -o '{.*}' "$TMP_FILE" | head -1)
if [ -z "$JSON" ]; then
  # 複数行JSONに対応
  JSON=$(cat "$TMP_FILE" | python3 -c "
import sys, re
content = sys.stdin.read()
match = re.search(r'\{[\s\S]*\}', content)
if match: print(match.group())
")
fi

if [ -z "$JSON" ]; then
  echo "エラー: キーワード調査に失敗しました"
  cat "$TMP_FILE"
  rm -f "$TMP_FILE"
  exit 1
fi

echo "$JSON" > "$TMP_FILE"
echo "調査完了。記事アイデアを取得しました。"
echo ""

# Step2: 記事アイデアを取り出して順番に生成
node - "$TMP_FILE" "$SCRIPT_DIR" <<'EOF'
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const [,, tmpFile, scriptDir] = process.argv;
const raw = fs.readFileSync(tmpFile, 'utf-8');

let data;
try {
  data = JSON.parse(raw);
} catch(e) {
  console.error('JSONパースエラー:', e.message);
  process.exit(1);
}

const ideas = data.article_ideas || [];
console.log(`=== ${ideas.length}本の記事を順番に生成します ===\n`);

for (const [i, idea] of ideas.entries()) {
  console.log(`[${i+1}/${ideas.length}] 生成中: ${idea.title}`);
  console.log(`  キーワード: ${idea.keyword}`);
  console.log(`  切り口: ${idea.angle}`);

  const prompt = `
あなたは37Design（株式会社37Design）のブログ記事ライターです。
代表は古田 健（ふるた けん）です。

以下のテーマでブログ記事を書いて、JSONで返してください。

テーマ: ${idea.title}
狙うキーワード: ${idea.keyword}
差別化の切り口: ${idea.angle}
公開日: ${new Date().toISOString().split('T')[0]}

## 記事の要件
- 文字数: 3000〜5000字
- h2を5〜7個、各h2にh3を2〜3個
- 導入 → 問題深掘り → 解決策 → CTA → まとめ の構成
- 「こんにちは、37Design代表の古田です。」で書き始める
- targetKeywordをh1・導入文・見出しに自然に含める
- 禁止表現: 絶対に/確実に/100%/必ず/業界No.1

## 返却フォーマット（JSONのみ。説明文不要）
{
  "title": "記事タイトル",
  "description": "120〜160字のmeta description",
  "slug": "英数字とハイフンのみ",
  "category": "AI | 業務自動化 | マーケティング | CRM | SEO",
  "tags": ["タグ1", "タグ2", "タグ3"],
  "targetKeyword": "${idea.keyword}",
  "body": "Markdown本文（frontmatterなし）"
}
`.trim();

  try {
    const today = new Date().toISOString().split('T')[0];
    execSync(
      `echo ${JSON.stringify(prompt)} | env -u CLAUDECODE claude -p | node "${path.join(scriptDir, 'save-article.js')}" "${today}"`,
      { stdio: 'inherit', shell: true }
    );
  } catch(e) {
    console.error(`  エラー: ${e.message}`);
  }
  console.log('');
}

fs.unlinkSync(tmpFile);
console.log('=== 全記事の生成が完了しました ===');
EOF
