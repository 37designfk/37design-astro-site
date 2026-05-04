# Customer Voices Source

37Designサイトのお客様の声・導入事例で使う一次データの取得元。

## 取得ディレクトリ

- Source: `~/customer-voices/`
- Canonical data: `~/customer-voices/voices.json`
- Local display component: `src/components/Testimonials.astro`

## 公開ルール

- `approval: "approved"` のボイスだけをサイト掲載対象にする
- 実名公開は本人許諾があるものだけにする
- 許諾が未取得、または匿名運用のものは `public_label` を使う
- `client_label` は内部確認用として扱い、サイトには出さない

## 2026-05-04 反映分

`~/customer-voices/voices.json` から `approval: "approved"` の6件を、匿名表記で `Testimonials.astro` に反映。

### やったこと

- 37Designサイト側の参照メモとして、このファイルを追加
- `src/components/Testimonials.astro` のダミー testimonial 3件を、`~/customer-voices/voices.json` の approved 6件に差し替え
- サイト上には `public_label` 相当の匿名表記だけを表示
- `client_label` はサイトに出さず、内部確認用として扱う
- 各カードに `data-source-id` を付与し、`voices.json` の `id` と照合できるようにした
- `Testimonials.astro` 冒頭に取得元コメントを追加

### 反映ID

- `v-2026-05-001`
- `v-2026-05-002`
- `v-2026-05-003`
- `v-2026-05-004`
- `v-2026-05-005`
- `v-2026-05-006`
