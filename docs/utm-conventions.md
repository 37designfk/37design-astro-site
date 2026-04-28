# 37Design UTM パラメータ規約

GA4 でDirectが54%もある状態は、流入経路の可視性がゼロに近い状態。これを「どの発信経路から来たか」が分かる状態に揃えるための規約。

## なぜ必要か

- LINE・名刺QR・メール署名・SNSプロフィールから来た訪問者は、GA4 では多くがDirectとして記録される（リファラがブラウザに渡らない）
- どこに投資すべきか・どの導線が効いているかが定量的に判断できない
- 改善ループが回らない（=広告費・コンテンツ投資の無駄打ち）

UTMを統一するだけで、月次レポートで「どのチャネルが何件のセッション・CVを生んだか」が分かるようになる。

---

## 標準形

```
https://37design.co.jp/<path>/?utm_source=<source>&utm_medium=<medium>&utm_campaign=<campaign>&utm_content=<content>
```

| パラメータ | 必須 | 役割 | 値の例 |
|---|---|---|---|
| `utm_source` | 必須 | どこから来たか（媒体名） | `line`, `x`, `instagram`, `threads`, `facebook`, `linkedin`, `youtube`, `mautic`, `namecard`, `email_signature` |
| `utm_medium` | 必須 | 媒体カテゴリ | `social`, `email`, `qr`, `referral`, `cpc`, `signature` |
| `utm_campaign` | 必須 | キャンペーン/案件名 | `ai_advisor_2026q2`, `monthly_newsletter_202604`, `subsidy_blog_promo` |
| `utm_content` | 推奨 | 同一キャンペーン内の枝分かれ識別 | `cta_button`, `bio_link`, `top_post`, `qr_back` |
| `utm_term` | 任意 | 検索広告キーワード（広告のみ） | `ai顧問` |

### 値のルール

- 半角小文字 + アンダースコアのみ（スペース・大文字・全角は禁止）
- ASCII のみ、日本語・絵文字は使わない（GA4 で文字化けする経験あり）
- 値はあとから絞れるよう「源 / 媒体 / キャンペーン」の三層で必ず書く
- 1度決めた値は3ヶ月は変えない（移動平均で比較できなくなる）

---

## 主要発信経路の標準値

| 経路 | source | medium | campaign（例） | content（例） |
|---|---|---|---|---|
| LINE 公式アカウント | `line` | `social` | キャンペーン名 | `card_<n>` |
| X プロフィール | `x` | `social` | `bio_link` | `pinned_post` |
| Instagram プロフィール | `instagram` | `social` | `bio_link` | `linkinbio` |
| Threads プロフィール | `threads` | `social` | `bio_link` | — |
| Facebook ページ | `facebook` | `social` | `bio_link` | — |
| LinkedIn 個人 | `linkedin` | `social` | `bio_link` | — |
| YouTube 概要欄 | `youtube` | `social` | 動画タイトル slug | `description` |
| 名刺裏 QR | `namecard` | `qr` | `namecard_2026q2` | `back_qr` |
| メール署名 | `email_signature` | `signature` | `monthly_<yyyymm>` | `signature_link` |
| Mautic ニュースレター | `mautic` | `email` | `newsletter_<yyyymm>` | 各リンク slug |
| Mautic キャンペーンメール | `mautic` | `email` | キャンペーン slug | 各リンク slug |
| Google 広告 | `google` | `cpc` | 広告グループ名 | `ad_<id>` |
| Meta 広告 | `meta` | `cpc` | 広告セット名 | `creative_<id>` |
| メディア記事 | 媒体ドメイン | `referral` | 記事 slug | — |

---

## 具体例

### LINE 公式アカウントから AI顧問LP

```
https://37design.co.jp/lp/ai-consulting/?utm_source=line&utm_medium=social&utm_campaign=line_richmenu_202604&utm_content=ai_advisor
```

### 名刺裏 QR から 会社案内

```
https://37design.co.jp/?utm_source=namecard&utm_medium=qr&utm_campaign=namecard_2026q2&utm_content=back_qr
```

### メール署名から問い合わせフォーム

```
https://37design.co.jp/contact/?utm_source=email_signature&utm_medium=signature&utm_campaign=monthly_202604&utm_content=signature_link
```

### Mautic ニュースレター（4月号）の本文リンク

```
https://37design.co.jp/blog/sme-ai-subsidy-guide-2026/?utm_source=mautic&utm_medium=email&utm_campaign=newsletter_202604&utm_content=subsidy_article
```

---

## 運用フロー

1. **新しい発信媒体を作るとき** — このファイルにマッピングを追記してから、URL を発行する
2. **既存の発信を更新するとき** — campaign 値だけは月次でローテーション可能（例: `monthly_202604` → `monthly_202605`）。source/medium は固定
3. **計測** — GA4 の「集客」→「トラフィック獲得」レポートで `セッションのデフォルトチャネルグループ` ではなく `セッションの参照元 / メディア` を見る

## 既存リンクの差し替え対象

優先順位の高いものから、UTM 付きのリンクに差し替える。

- [ ] LINE 公式アカウントのリッチメニュー全リンク
- [ ] X プロフィールの bio リンク
- [ ] Instagram プロフィールの bio リンク
- [ ] 名刺裏 QR コード（次回名刺発注のタイミング）
- [ ] メール署名（古田さん用 / 共通テンプレ）
- [ ] Mautic 各キャンペーン本文内のリンク
- [ ] LinkedIn 個人プロフィール

---

## URL 生成ヘルパー

GA4 が公式に提供している Campaign URL Builder を使うと、フォーマット間違いを防げる:
https://ga-dev-tools.google/campaign-url-builder/

長い URL を短く配布したい場合は、自社で運用している短縮ドメインを使う（必要なら別途整備）。

---

最終更新: 2026-04-28
