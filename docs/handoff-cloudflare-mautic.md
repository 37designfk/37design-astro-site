# Cloudflare Access + Mautic API 設定 引き継ぎ指示書

## 背景

Mautic（m6.37d.jp）のAPIがCloudflare WAFにブロックされて500エラーになっている。
Cloudflare Access の Service Token を使って、APIパスだけ認証付きでバイパスする。

---

## 1. Cloudflare Access 設定（これをやる）

### 前提情報
- **Account ID**: `749d8afe4f0bf2edce33435d85662803`
- **Mauticドメイン**: `m6.37d.jp`
- **保護対象パス**: `/api/*`
- **Mautic APIのBasic Auth**: ユーザー名 `37design`（パスワードはオーナーが知っている）

### 手順

#### Step 1: Cloudflare APIトークンを取得
1. https://dash.cloudflare.com/profile/api-tokens を開く
2. 「Create Token」→「Custom token」
3. 権限:
   - `Account > Access: Service Tokens > Edit`
   - `Account > Access: Apps and Policies > Edit`
4. Account: 自分のアカウントを選択
5. トークンをコピー

#### Step 2: Service Token を作成
```bash
CF_API_TOKEN="<Step1で取得したトークン>"
CF_ACCOUNT_ID="749d8afe4f0bf2edce33435d85662803"

curl -X POST "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/access/service_tokens" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"name":"Mautic API - Claude MCP","duration":"8760h"}' | python3 -m json.tool
```

**重要**: レスポンスの `client_id` と `client_secret` を控える。`client_secret` は一度しか表示されない。

#### Step 3: Access Application を作成
```bash
# Step 2で取得した値
SERVICE_TOKEN_ID="<Step2のレスポンスのid>"

curl -X POST "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/access/apps" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "Mautic API",
    "domain": "m6.37d.jp/api/*",
    "type": "self_hosted",
    "session_duration": "24h",
    "policies": [
      {
        "name": "Service Token Only",
        "decision": "non_identity",
        "include": [
          {
            "service_token": {
              "token_id": "'"${SERVICE_TOKEN_ID}"'"
            }
          }
        ]
      }
    ]
  }' | python3 -m json.tool
```

#### Step 4: MCP Mautic の設定を更新

Claude Code の MCP設定（Mauticサーバー）に、以下のヘッダーを追加:
- `CF-Access-Client-Id`: Step 2 の `client_id`
- `CF-Access-Client-Secret`: Step 2 の `client_secret`

MCP設定ファイルの場所を確認して、Mautic MCPサーバーの環境変数またはヘッダー設定に追加する。

#### Step 5: 動作確認
```bash
# curlで確認
curl -s -w '\n%{http_code}' \
  -H "CF-Access-Client-Id: <client_id>" \
  -H "CF-Access-Client-Secret: <client_secret>" \
  -u "37design:<mauticパスワード>" \
  "https://m6.37d.jp/api/emails?limit=1"
```
200が返ればOK。

---

## 2. Mautic ステップメール 現在の状態

### 投入済みメールテンプレート（DB直接投入済み）

| ID | シリーズ | 名前 | 配信タイミング |
|----|---------|------|--------------|
| 1 | - | 問い合わせ通知 | - |
| 2 | AI診断 1/5 | 診断結果レポート | 即時 |
| 3 | AI診断 2/5 | まず使うべき3つのAIツール | 2日後 |
| 4 | AI診断 3/5 | 導入事例：月40時間削減 | 5日後 |
| 5 | AI診断 4/5 | AI導入でよくある失敗3選 | 8日後 |
| 6 | AI診断 5/5 | 無料相談のご案内 | 12日後 |
| 11 | ROI 1/5 | シミュレーション結果レポート | 即時 |
| 12 | ROI 2/5 | 今日から使える無料AIツール5選 | 2日後 |
| 13 | ROI 3/5 | 導入事例：月40時間削減の実例 | 5日後 |
| 14 | ROI 4/5 | AI導入の落とし穴と回避法 | 8日後 |
| 15 | ROI 5/5 | 無料相談のご案内 | 12日後 |
| 16 | サイト診断 1/5 | 診断結果レポート | 即時 |
| 17 | サイト診断 2/5 | 自分でできる表示速度改善5つ | 2日後 |
| 18 | サイト診断 3/5 | サイト改善で問い合わせ2倍の事例 | 5日後 |
| 19 | サイト診断 4/5 | やってはいけないサイト改善 | 8日後 |
| 20 | サイト診断 5/5 | 無料相談のご案内 | 12日後 |

### HTMLテンプレートのローカルコピー
```
~/37design-astro-site/docs/mautic-emails/
├── README.md                  ← 全体まとめ
├── roi-1-result-report.html
├── roi-2-free-tools.html
├── roi-3-case-study.html
├── roi-4-pitfalls.html
├── roi-5-cta.html
├── audit-1-result-report.html
├── audit-2-speed-tips.html
├── audit-3-case-study.html
├── audit-4-mistakes.html
└── audit-5-cta.html
```

※ AI診断シリーズ（ID 2-6）はMautic API経由で作成済みのためローカルHTMLなし。

---

## 3. まだやっていないこと（Cloudflare Access設定後に実施）

### 3-1. Mauticフォーム作成（3つ）
各ツールからのリード取得用フォーム。フィールド: firstname, email, company

| フォーム | 対応ツール | 対応ステップメール |
|---------|-----------|-----------------|
| AI活用度診断フォーム | /tools/ai-assessment/ | ID 2-6 |
| ROIシミュレーターフォーム | /tools/roi-calculator/ | ID 11-15 |
| サイト診断フォーム | /tools/site-audit/ | ID 16-20 |

### 3-2. Mauticキャンペーン作成（3つ）
各フォームに紐づくステップメール自動配信キャンペーン:
- トリガー: フォーム送信
- アクション: 5通のメールを間隔を空けて配信
  - 1通目: 即時
  - 2通目: 2日後
  - 3通目: 5日後
  - 4通目: 8日後
  - 5通目: 12日後

### 3-3. ツールページの formId 更新
作成したフォームIDを各ツールページに設定:
- `src/pages/tools/ai-assessment.astro` → formId を実際のIDに
- `src/pages/tools/roi-calculator.astro` → formId を実際のIDに
- `src/pages/tools/site-audit.astro` → formId を実際のIDに

### 3-4. Mauticカスタムフィールド作成
- `ai_score`: AI診断スコア（数値）をコンタクトに保存するため

---

## 4. Mauticサーバー情報

- **URL**: https://m6.37d.jp
- **Docker**: `mautic6-web`（Web）、`mautic6-db`（MariaDB 10.6）
- **DB**: `mautic6` / ユーザー `mautic` / パスワード `strongpass`
- **テーブルプレフィックス**: `strongpass`（※設定ミスだがそのまま運用中）
- **PHP memory_limit**: 512M に変更済み（`/usr/local/etc/php/conf.d/custom-memory.ini`）
  - ただしコンテナ再起動で消える可能性あり
  - 永続化するには docker-compose.yml にボリュームマウント追加が望ましい
- **APIユーザー**: `37design`
- **SSH**: `ssh u`（Cloudflared proxy経由）

### PHP memory_limit の永続化（推奨）
```bash
ssh u
# mautic6のdocker-compose.ymlに以下を追加:
# volumes:
#   - ./php-custom.ini:/usr/local/etc/php/conf.d/custom-memory.ini
# そしてphp-custom.iniに memory_limit=512M と書く
```

---

## 5. 対応ツールページ（作成済み）

| ツール | URL | ファイル |
|-------|-----|---------|
| AI活用度診断 | /tools/ai-assessment/ | src/pages/tools/ai-assessment.astro |
| ROIシミュレーター | /tools/roi-calculator/ | src/pages/tools/roi-calculator.astro |
| サイト診断 | /tools/site-audit/ | src/pages/tools/site-audit.astro |

---

## 6. この指示書のファイル参照まとめ

| 何を見たいか | ファイルパス |
|------------|-----------|
| この指示書 | `docs/handoff-cloudflare-mautic.md` |
| メールHTML一覧・配信スケジュール | `docs/mautic-emails/README.md` |
| ROIメールHTML | `docs/mautic-emails/roi-*.html` |
| サイト診断メールHTML | `docs/mautic-emails/audit-*.html` |
| AI診断ツール | `src/pages/tools/ai-assessment.astro` |
| ROIシミュレーター | `src/pages/tools/roi-calculator.astro` |
| サイト診断ツール | `src/pages/tools/site-audit.astro` |
| LPレイアウト | `src/layouts/LPLayout.astro` |
| LP Heroコンポーネント | `src/components/lp/Hero.astro` |
| プロジェクトメモリ | `.claude/projects/-Users-kenfuruta-37design-astro-site/memory/MEMORY.md` |
