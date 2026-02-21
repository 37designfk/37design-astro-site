# 37Design マーケティングOS 共通ルール

## プロジェクト概要
- **フレームワーク**: Astro 5 + Tailwind CSS 4
- **サイト**: https://37design.co.jp
- **GitHub**: 37designfk/37design-astro-site
- **用途**: マーケティングOS による自動サイト運用

## 技術ルール
- Tailwind CSSでスタイリング（カスタムCSS最小限）
- 変更前に必ず `git checkout -b task-{id}-{slug}`
- `npm run build` が通ることを確認してからマージ
- ビルド失敗時はエラー修正、最大3回（fix_iteration_count）で打ち切り
- 成功時のみ main にマージ
- 1回の作業で変更するファイルは最大5つまで

## Git設定
```bash
git config user.name "37Design Marketing OS"
git config user.email "os@37d.jp"
git config pull.rebase false
```

## コンテンツタイプ
| タイプ | ディレクトリ | レイアウト | CLAUDE.md |
|--------|------------|----------|-----------|
| ブログ記事 | src/content/blog/ | BlogLayout.astro | CLAUDE-BLOG.md |
| 固定ページ | src/pages/ | Layout.astro | CLAUDE-PAGES.md |
| LP | src/pages/lp/ | LPLayout.astro | CLAUDE-LP.md |

## 禁止表現
以下の表現は絶対に使用しない:
- 絶対に / 確実に / 100% / 必ず治る / 副作用なし
- 業界No.1 / 世界一（根拠なし）
- その他、薬機法・景品表示法に抵触する表現

## 品質ゲートv0（自動チェック）
### ブログ記事
- 本文3000字以上
- h2が5個以上
- 内部リンク3本以上
- meta description設定済み
- 全画像にalt属性
- Article構造化データあり
- 禁止表現なし

### LP
- CTAが3箇所以上
- お客様の声/実績セクションあり
- モバイルファースト構造
- 構造化データあり
- 禁止表現なし
- 全画像にalt属性

### 固定ページ
- 回遊リンク2本以上
- 全画像にalt属性

## デザインシステム
- **Primary**: #0a0f1e (dark) 〜 #f0f4fa (light)
- **Accent**: #f5d020 (yellow/gold)
- **CTA (LP)**: bg-orange-500 hover:bg-orange-600
- **Font**: Noto Sans JP
- **コンテナ**: max-w-6xl mx-auto px-4 sm:px-6 lg:px-8

## 会社情報
- **社名**: 株式会社37Design
- **代表**: 古田 健（ふるた けん）
- **設立**: 2012年6月1日
- **本社**: 兵庫県神戸市北区桂木2-35-C604
- **東京営業所**: 東京都中央区銀座4-10-14 ACN銀座4ビルディング11F
- **電話**: 080-2412-2556
- **メール**: info@37design.co.jp

## 重要なコマンド
```bash
npm run dev      # 開発サーバー (localhost:4321)
npm run build    # プロダクションビルド
npm run preview  # ビルドプレビュー
```
