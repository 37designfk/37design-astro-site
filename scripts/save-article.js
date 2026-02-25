#!/usr/bin/env node
// generate-article.sh から呼ばれる。標準入力からJSONを受け取りMarkdownファイルを生成する

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

const today = process.argv[2] || new Date().toISOString().split('T')[0];
const blogDir = path.join(__dirname, '../src/content/blog');

let raw = '';
process.stdin.on('data', chunk => raw += chunk);
process.stdin.on('end', () => {
  // JSON部分だけ抽出 - 最も大きい {} ブロックを採用
  const matches = [];
  let depth = 0, start = -1;
  for (let i = 0; i < raw.length; i++) {
    if (raw[i] === '{') { if (depth === 0) start = i; depth++; }
    if (raw[i] === '}') { depth--; if (depth === 0 && start >= 0) { matches.push(raw.slice(start, i + 1)); start = -1; } }
  }
  if (matches.length === 0) {
    console.error('JSONが見つかりませんでした。出力:');
    console.error(raw.substring(0, 500));
    process.exit(1);
  }
  // 最も長いブロックを使う
  const jsonStr = matches.sort((a, b) => b.length - a.length)[0];

  let article;
  try {
    article = JSON.parse(jsonStr);
  } catch (e) {
    console.error('JSONパースエラー:', e.message);
    console.error(jsonStr.substring(0, 500));
    process.exit(1);
  }

  const { title, description, category, targetKeyword, body } = article;
  const slug = article.slug || 'untitled-' + Date.now();
  const tags = Array.isArray(article.tags) ? article.tags : [];

  if (!title || !body) {
    console.error('エラー: title または body が空です');
    process.exit(1);
  }

  const sanitize = (s) => (s || '').replace(/"/g, '\\"').replace(/\n/g, ' ');

  const frontmatter = `---
title: "${sanitize(title)}"
description: "${sanitize(description)}"
publishDate: ${today}
author: "古田 健"
category: "${sanitize(category || 'AI')}"
tags: [${tags.map(t => `"${sanitize(t)}"`).join(', ')}]
targetKeyword: "${sanitize(targetKeyword || '')}"
structuredDataType: "Article"
---

`;

  const filepath = path.join(blogDir, `${slug}.md`);
  fs.writeFileSync(filepath, frontmatter + body);
  console.log(`✅ 保存完了: src/content/blog/${slug}.md`);

  // n8n にタスクログを送信
  const N8N_URL = 'https://n8n-onprem.37d.jp/webhook/37design-log-task';
  fetch(N8N_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ type: 'blog_generate', title, slug, category, status: 'done', priority: 'medium' }),
  }).catch(e => console.error('n8nログ送信失敗:', e.message));
});
