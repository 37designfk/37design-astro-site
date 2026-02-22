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
  // JSON部分だけ抽出（claude が前後に説明文を入れても対応）
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) {
    console.error('JSONが見つかりませんでした。出力:');
    console.error(raw);
    process.exit(1);
  }

  let article;
  try {
    article = JSON.parse(match[0]);
  } catch (e) {
    console.error('JSONパースエラー:', e.message);
    console.error(raw);
    process.exit(1);
  }

  const { title, description, slug, category, tags, targetKeyword, body } = article;

  const frontmatter = `---
title: "${title}"
description: "${description}"
publishDate: ${today}
author: "古田 健"
category: "${category}"
tags: [${tags.map(t => `"${t}"`).join(', ')}]
targetKeyword: "${targetKeyword}"
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
  }).catch(() => {}); // 失敗しても無視
});
