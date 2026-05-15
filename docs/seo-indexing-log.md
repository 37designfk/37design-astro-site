# SEO インデックスログ

37Design ブログのインデックス問題を「**検知 → 仮説 → 対策 → 結果**」で追跡するナレッジ蓄積。
データの正は `docs/_indexing-history.json`（機械可読・毎日のスナップショット）。本ファイルは人間が読む解釈・学び・個別ケース。

## 運用フロー

1. `scripts/check-indexing.py` を daily-loop.sh から毎日実行
2. 全記事のGSC状態と特徴量（字数・h2数・被リンク数）を `_indexing-history.json` にスナップショット追記
3. 未掲載検知時 or 状態変化時に Discord 通知 + 本ファイルに個別ケース追加
4. 対策実施後、1週・2週・4週後の状態変化を「結果」欄に追記
5. 3-5件パターンが揃ったら **学び** セクションに昇格

## ステータス用語

| ステータス | 意味 | 解釈 |
|---|---|---|
| **PASS** | インデックス済み | 正常 |
| **Discovered - currently not indexed** | 発見されたがクロール後回し | 重要度低判定 = **被リンク不足 / サイト権威性不足** |
| **Crawled - currently not indexed** | クロール済みだが入らない | 内容の質判定 = **独自性不足 / 重複扱い / 低価値** |
| **Duplicate, Google chose different canonical** | 重複扱い | 別ページがcanonical指定された |
| **NEUTRAL - URL is unknown to Google** | 未発見 | sitemap反映前 or 完全孤立 |

---

## 学び（実データから帰納したパターン）

### L1. 被リンク数がインデックス可否を強く規定する（2026-05-14 確定）

50記事スナップショット時点:

| 区分 | 件数 | 平均字数 | 平均h2 | 平均h3 | **平均被リンク数** |
|---|---|---|---|---|---|
| インデックス済 | 45 | 5552 | 6.8 | 17.0 | **6.6** |
| 未掲載 | 5 | 5386 | 7.0 | 19.8 | **2.0** |

字数・見出し数では差がない。**被リンク数が3分の1以下**になっているのが決定的な違い。
→ 新規記事公開時は必ず2-3本以上の被リンクを他記事から張る運用が必須。

### L2. 「Discovered - not indexed」と「Crawled - not indexed」は別の対策が必要

- **Discovered**: 被リンクを増やせば改善する見込み（重要度判定の問題）
- **Crawled**: 内容の独自性が問題。被リンク追加だけでは効かない。一次経験・固有数値・古田口調を入れた**リライト**が必要

### L3. 被リンク0本でもインデックスされる例外がある

`generative-ai-consulting-fees-2026` (被リンク0だがPASS) のような例外あり。タイトル・キーワードの独自性・検索需要・先行クロールタイミングが寄与している可能性。逆に被リンク3本でも未掲載の `sme-ai-ec-online-shop-guide-2026` がある。被リンクは必要条件だが十分条件ではない。

---

## 現状サマリ（2026-05-14 初回スナップショット）

- 総記事: 50本
- インデックス済: 45本（90%）
- 未掲載: 5本（10%）

## 個別ケース（時系列・新しい順）

### 2026-05-14 google-ai-mode-sme-seo-strategy-2026
- URL: https://37design.co.jp/blog/google-ai-mode-sme-seo-strategy-2026/
- 公開: 2026-05-10（4日経過）/ 字数 4960 / h2: 7 / h3: 21 / **被リンク: 0**
- ステータス: `Discovered - currently not indexed`
- **仮説**: 公開直後＋完全孤立。Googleはsitemap発見済みだがクロール優先度が低い
- **対策**:
  - [ ] AI顧問関連の柱記事から2-3本のリンクを張る
  - [x] 2026-05-14: GSC UIから「インデックス登録をリクエスト」実行
- **結果**: 2026-05-14リクエスト直後。被リンク0のままなので、リクエストでクロールは進んでもPASSしない可能性あり。明朝のdaily-loop自動診断で状態確認

### 2026-05-14 sme-ai-ec-online-shop-guide-2026
- URL: https://37design.co.jp/blog/sme-ai-ec-online-shop-guide-2026/
- 公開: 2026-04-30（14日経過）/ 字数 4116 / h2: 6 / h3: 14 / 被リンク: 3 (2026-05-14対策で追加)
- ステータス: `Discovered - currently not indexed`
- **仮説**: 公開直後は被リンク0で孤立。L1パターンに合致
- **対策**:
  - [x] 2026-05-14: 3記事から被リンク追加（sales-demand-forecast / image-generation-design / marketing-low-cost-steps）
  - [x] 2026-05-14: GSC UIから「インデックス登録をリクエスト」実行
- **結果**: 2026-05-14 被リンク追加＋手動リクエスト直後。**L1パターン対策の検証ケース**。PASSに変われば「被リンク3本+手動リクエスト」で Discovered→PASS が再現可能と判定

### 2026-05-14 ai-replaces-consultants-truth
- URL: https://37design.co.jp/blog/ai-replaces-consultants-truth/
- 公開: 2026-04-30 / 字数 5376 / h2: 7 / h3: 19 / **被リンク: 1**（generative-ai-consulting-fees-2026のみ）
- ステータス: `Discovered - currently not indexed`
- **仮説**: 被リンク1本では権威伝播が弱い
- **対策**:
  - [ ] AI顧問関連の柱記事から2-3本のリンクを張る
  - [x] 2026-05-14: GSC UIから「インデックス登録をリクエスト」実行
- **結果**: 2026-05-14リクエスト直後。被リンク追加なしでリクエストのみの実験ケース。被リンク不足のままPASSするか観察

### 2026-05-14 ai-advisor-industry-roadmap-2026
- URL: https://37design.co.jp/blog/ai-advisor-industry-roadmap-2026/
- 公開: 2026-04-30 / 字数 6160 / h2: 9 / h3: 30 / 被リンク: 2 / Last Crawl: 2026-04-30
- ステータス: `Crawled - currently not indexed`
- **仮説**: クロール済みだが内容判定で蹴られた。h3が30個と多くテンプレ感が強い疑い。AI生成の典型パターン
- **対策**:
  - [ ] 一次情報注入リライト（voices/古田口調を使った新プロンプトで再生成）
  - [ ] 見出し構造を整理（h3を15個以下に削減）
  - [x] 2026-05-14: GSC UIから「インデックス登録をリクエスト」実行（リライト前の再判定実験）
- **結果**: 2026-05-14リクエスト直後。**Crawled-not-indexedはリクエストで動くか実験**。同内容での再判定なので変わらない可能性が高いが、データとして取る価値あり

### 2026-05-14 ai-advisor-failure-cases-2026
- URL: https://37design.co.jp/blog/ai-advisor-failure-cases-2026/
- 公開: 2026-04-30 / 字数 6316 / h2: 6 / h3: 15 / 被リンク: 4 / Last Crawl: 2026-04-30
- ステータス: `Crawled - currently not indexed`
- **仮説**: 被リンクは十分（4本）。内容の独自性が問題。失敗事例なのに固有名詞・具体数値が乏しいAI記事の典型と推定
- **対策**:
  - [ ] 一次情報注入リライト（voices 6件 と古田口調を反映）
  - [ ] 古田さんの実顧客失敗事例を1件、固有業種・具体的失敗内容で挿入
  - [x] 2026-05-14: GSC UIから「インデックス登録をリクエスト」実行（リライト前の再判定実験）
- **結果**: 2026-05-14リクエスト直後。**被リンク十分(4本)・Crawled-not-indexedで再リクエスト**という最も「リクエストだけで動くか」の純粋実験。動かなければL2（Crawled-not-indexedはリライトが必要）が強く支持される

---

## 対策履歴（_indexing-history.json のactionsと対応）

| 日付 | 対象スラッグ | アクション | 詳細 |
|---|---|---|---|
| 2026-05-14 | sme-ai-ec-online-shop-guide-2026 | 被リンク追加 | sme-ai-sales-demand-forecast-2026 / sme-ai-image-generation-design-2026 / sme-ai-marketing-low-cost-steps の3記事に文中リンク追加 |
| 2026-05-14 | プロンプト全体 | AI判定回避策の本格導入 | scripts/build-blog-context.mjs 作成。voices(approved)とfuruta_voice.mdをdaily-loop.shプロンプトに必須素材として注入。h2/字数の可変化、固定書き出し廃止、Claude定型句を禁止フレーズに追加 |
| 2026-05-14 | 未掲載5本全部 | GSC手動リクエスト | 古田さんがGSC UIから5本全件「インデックス登録をリクエスト」実行。検証ケース4種（被リンク補強済+リクエスト / 被リンクなし+リクエストのみ / Crawled-not-indexed+リクエストのみ×2）の対照実験 |
