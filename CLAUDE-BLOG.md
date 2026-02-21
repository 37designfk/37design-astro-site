# ブログ記事ルール

## 構成
- 導入 → 問題深掘り → 解決策 → LP誘導CTA → まとめ
- 文字数: 3000〜5000字
- h2は5〜7個、各h2にh3を2〜3個

## ファイル配置
- `src/content/blog/{slug}.md`
- 画像: `public/images/blog/{slug}/`

## Frontmatter
```yaml
---
title: "記事タイトル"
description: "120〜160字のmeta description"
publishDate: 2026-02-21
author: "古田 健"
category: "AI"  # AI, 業務自動化, マーケティング, CRM, お知らせ, SEO, LP制作
tags: ["タグ1", "タグ2"]
image: "/images/blog/{slug}/hero.jpg"
targetKeyword: "メインキーワード"
relatedArticles: ["slug1", "slug2"]
targetLP: "/lp/service-name"
structuredDataType: "Article"  # Article, HowTo, FAQPage
---
```

## SEOルール
- 対象LPへの内部リンクを最低3箇所
- 関連記事同士も相互リンク
- 構造化データ（Article, FAQ）を含める
- 画像にはalt属性を必ず設定
- meta descriptionを120〜160字で設定
- targetKeywordをh1, 導入文, 見出しに自然に含める

## レイアウト
- BlogLayout.astro を使用
- 画像はAstroのImageコンポーネントで遅延読み込み

## カテゴリー
| カテゴリー | 対象LP | 色 |
|-----------|--------|-----|
| AI | AI顧問サービス | blue |
| 業務自動化 | AI自動化コンサル | green |
| マーケティング | マーケティングOS | purple |
| CRM | - | orange |
| SEO | マーケティングOS | teal |
| LP制作 | LP自動生成サービス | pink |
| お知らせ | - | gray |
