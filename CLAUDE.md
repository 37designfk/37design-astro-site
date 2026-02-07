# 株式会社37Design コーポレートサイト開発ログ

## プロジェクト概要

- **フレームワーク**: Astro 5.17.1
- **スタイリング**: Tailwind CSS 4.1.18
- **開発環境**: `/Users/kenfuruta/astro-site`
- **開発サーバー**: `npm run dev` (http://localhost:4321)

## 会社情報

- **社名**: 株式会社37Design
- **代表者**: 古田 健（ふるた けん）
- **設立**: 2012年6月1日
- **本社**: 〒651-1223 兵庫県神戸市北区桂木2-35-C604
- **東京営業所**: 〒104-0061 東京都中央区銀座4-10-14 ACN銀座4ビルディング11F
- **電話**: 080-2412-2556
- **メール**: info@37design.co.jp
- **LINE**: https://jmp9xv65.autosns.app/line

## 2026年2月7日 作業内容

### 1. ページ作成（計12ページ）

#### メインページ
- ✅ トップページ (`/`)
- ✅ サービス一覧 (`/service`)
- ✅ 会社概要 (`/company`)
- ✅ 代表挨拶 (`/greeting`)
- ✅ 採用情報 (`/recruit`)
- ✅ ニュースレター登録 (`/newsletter`)
- ✅ お問い合わせ (`/contact`)

#### 法的ページ
- ✅ プライバシーポリシー (`/privacy`)
- ✅ 特定商取引法表記 (`/tokushoho`)

#### コンテンツページ
- ✅ お知らせ一覧 (`/news`)
- ✅ ブログ一覧 (`/blog`)
- ✅ ブログ個別記事 (`/blog/[slug]`)
- ✅ カテゴリーアーカイブ (`/blog/category/[category]`)

### 2. サービス内容の拡充

#### AI開発・導入支援（8サービス）
- AI構築フルパッケージ
- ChatGPT/Claude活用支援
- 社内AIチャットボット構築
- AI業務効率化コンサルティング
- LexionHub Sales（営業音声AI解析）
- LexionHub Fortune（四柱推命×AI）
- LexionHub Autopoiesis（自走型ビジネス構築）
- カスタムAI開発

#### 業務自動化・RPA（7サービス）
- n8n導入・ワークフロー構築
- Make（旧Integromat）活用支援
- Zapier連携構築
- Power Automate導入支援
- 請求書・見積書自動生成
- 在庫管理自動化
- 日報・レポート自動生成

#### CRM・顧客管理（7サービス）
- EspoCRM導入・カスタマイズ
- Invoice Ninja導入支援
- Mautic導入・MA構築
- 顧客データ一元管理
- メールマーケティング自動化
- リード育成フロー構築
- カスタマーサポート最適化

### 3. ブログ機能の実装

#### コンテンツコレクション設定
- `/src/content/config.ts` 作成
- カテゴリー: AI、業務自動化、マーケティング、CRM、お知らせ
- マークダウン形式で記事管理

#### サンプル記事（3本）
1. 中小企業のためのAI導入完全ガイド
2. 業務自動化で失敗しないための5つのポイント
3. 顧客管理を変えた！不動産会社のCRM導入成功事例

#### カテゴリーアーカイブ
- カテゴリー別記事一覧ページ
- カテゴリーフィルター機能
- カテゴリー別色分け

### 4. 画像アセット

#### 追加した画像
- `/public/images/hero-team.jpg` - ヒーロー画像（ビジネスウーマン）
- `/public/images/service-automation.png` - 業務自動化サービス画像
- `/public/images/service-crm.jpg` - CRMサービス画像
- `/public/images/service-ai.jpg` - AIサービス画像
- `/public/images/case-dashboard.jpg` - 事例：製造業ダッシュボード
- `/public/images/case-crm.jpg` - 事例：不動産CRM
- `/public/images/case-automation-flow.jpg` - 事例：自動化フロー
- `/public/images/ceo-photo.jpg` - 代表者写真
- `/public/images/ceo-signature.png` - 代表者サイン
- `/public/images/favicon.png` - ファビコン（黄色ヘキサゴン）

### 5. n8n/Mautic連携

#### Webhook設定
- **本番URL**: https://n8n-onprem.37d.jp/webhook/ai-diagnosis
- **用途**: お問い合わせフォーム送信

#### Mautic設定
- カスタムフィールド: `inquiry_type`, `inquiry_message`
- セグメント: `webformleads` (ID: 1)
- フォーム送信後、自動的にMauticに登録

### 6. デザイン調整

- モバイルレスポンシブ対応
- ヒーロー画像の表示順変更（モバイルで画像を上に）
- 代表挨拶ページにサイン画像追加
- Footerに全ページへのリンク追加

## ブログ記事の書き方

### ファイル作成場所
`/src/content/blog/ファイル名.md`

### 記事フォーマット
```markdown
---
title: "記事タイトル"
description: "記事の説明"
publishDate: 2026-02-07
author: "古田 健"
category: "AI" # AI, 業務自動化, マーケティング, CRM, お知らせ
tags: ["タグ1", "タグ2"]
---

# 見出し

本文をマークダウンで記述...
```

### カテゴリー
- **AI**: AI関連の記事
- **業務自動化**: n8n、RPA、自動化関連
- **マーケティング**: Webマーケティング、SEO等
- **CRM**: 顧客管理、営業管理関連
- **お知らせ**: 会社のお知らせ

## Dify AI チャットボット統合

### セットアップ手順
1. Difyをセルフホストでデプロイ（docker-compose）
2. リバースプロキシ設定（nginx）: https://dify.37d.jp
3. Difyでチャットアプリ作成
4. Claude APIキー設定
5. FAQデータベース構築（ナレッジベース）
6. 埋め込みトークンを取得
7. `src/components/ChatWidget.astro` の `DIFY_TOKEN` を更新

### 参考情報
- Dify GitHub: https://github.com/langgenius/dify
- Dify Docs: https://docs.dify.ai/

## 次回の予定

### ブログ記事自動化の検討
- AIによる記事生成の仕組み検討
- n8nを使った記事公開ワークフロー
- Mauticとの連携（記事公開通知メール）

### その他検討事項
- SEO対策（メタタグ最適化）
- サイトマップ生成
- Google Analytics連携
- OGP画像の設定

## 技術スタック

### フロントエンド
- Astro 5.17.1
- Tailwind CSS 4.1.18
- TypeScript

### バックエンド連携
- n8n (https://n8n-onprem.37d.jp)
- Mautic 6 (https://m6.37d.jp)

### デプロイ
- TBD（次回検討）

## 重要なコマンド

```bash
# 開発サーバー起動
npm run dev

# ビルド
npm run build

# プレビュー
npm run preview

# 新しいブログ記事作成
touch /Users/kenfuruta/astro-site/src/content/blog/new-article.md
```

## プロジェクト構成

```
astro-site/
├── src/
│   ├── components/     # 再利用可能なコンポーネント
│   │   ├── Header.astro
│   │   ├── Footer.astro
│   │   ├── Hero.astro
│   │   ├── Services.astro
│   │   ├── Cases.astro
│   │   ├── CTA.astro
│   │   └── FAQ.astro
│   ├── layouts/        # レイアウトコンポーネント
│   │   └── Layout.astro
│   ├── pages/          # ページ（ファイルベースルーティング）
│   │   ├── index.astro
│   │   ├── service.astro
│   │   ├── company.astro
│   │   ├── greeting.astro
│   │   ├── recruit.astro
│   │   ├── newsletter.astro
│   │   ├── contact.astro
│   │   ├── privacy.astro
│   │   ├── tokushoho.astro
│   │   ├── news.astro
│   │   └── blog/
│   │       ├── index.astro
│   │       ├── [slug].astro
│   │       └── category/
│   │           └── [category].astro
│   ├── content/        # コンテンツコレクション
│   │   ├── config.ts
│   │   └── blog/       # ブログ記事（マークダウン）
│   │       ├── ai-introduction-guide.md
│   │       ├── business-automation-tips.md
│   │       └── crm-success-story.md
│   └── styles/
│       └── global.css
├── public/
│   ├── images/         # 画像アセット
│   └── favicon.png
└── CLAUDE.md           # このファイル
```

## メモ

- 代表者の読み仮名: ふるた けん（「たけし」ではない）
- 2025年に体制変更（2024年ではない）
- WordPress管理実績: 300サイト以上
- heteml/ロリポップの管理情報は `~/wordpress-management/CLAUDE.md` 参照
- 自社サーバー情報は `~/self-hosted-automation/CLAUDE.md` 参照

---

最終更新: 2026年2月7日
