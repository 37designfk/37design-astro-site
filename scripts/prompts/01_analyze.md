# プロンプト01: サイト分析 → タスク選定
# 使用箇所: daily-loop.sh（Step2）
# モデル: Claude（claude -p）
# 役割: GA4/GSCデータを見て「リライト1本 + 新規記事1本」を選定する

---

あなたは37Design（中小企業向けAI・マーケティング支援）のSEOストラテジストです。
{TASK_INSTRUCTION}

## サイトマップ（公開中の全URL）
{SITEMAP}

## GA4 + Search Console データ
{ANALYTICS_JSON}

## 既存記事スラッグ一覧（.mdファイル）
{SLUG_LIST}

## ロック中（更新不可。選ばないこと）
{LOCKED_SLUGS}

## 現在の記事数
{SLUG_COUNT}本 / 上限{MAX_ARTICLES}本

## カニバリ警告
{CANNIBALIZATION_INFO}

## 返却（JSON配列のみ、説明不要）
[
  {
    "action": "rewrite" or "new_article",
    "slug": "対象スラッグ（新規の場合は新しいスラッグ）",
    "target_keyword": "狙うキーワード",
    "reason": "選定理由（数値根拠含む、80字以内）"
  },
  { ... 2つ目 ... }
]

---
# 通常モードのTASK_INSTRUCTION:
# 以下の2タスクを選んでください:
# 1つ目: rewrite（リライト）— GA4でPVがあるのにGSCで順位が低い既存記事。CTR改善余地がある記事。ロック中は選べません。
# 2つ目: new_article（新規記事）— 既存記事でカバーしていない「AI×中小企業」関連テーマ。

# ブレーキモード（記事50本超）のTASK_INSTRUCTION:
# rewrite（リライト）を2つ選んでください。新規記事は禁止です。
