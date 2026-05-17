---
title: "OpenClawとは?Claude Code互換OSSエージェント完全ガイド【経営者・エンジニア向け2026年最新】"
description: "週77時間Claude Codeを使うAI社長が、自社fork (37designfk/openclaw) で2号機運用中のOpenClawを完全解説。Claude Codeとの違い、できること、Windows/Mac/Dockerインストール、Claudeサブスクとの組み合わせ、セキュリティ・Banリスク対策まで日本語先行情報として2026年最新版で網羅。"
publishDate: 2026-05-18
lastModified: 2026-05-18
author: "古田 健"
category: "AI"
tags: ["OpenClaw", "Claude Code", "OSS", "AIエージェント", "Anthropic", "業務自動化", "経営者"]
targetKeyword: "OpenClaw"
relatedArticles: ["hermes-agent-complete-guide-for-business-2026", "claude-code-complete-guide-for-business-owners-2026", "claude-ai-complete-guide-sme-2026", "ai-agent-complete-guide-for-sme-2026-business"]
structuredDataType: "Article"
---

こんにちは、37Design代表の古田です。**週77時間Claude Codeを使うAI社長** として、自社で14プロダクトを並走運用しています (直近1週間ピーク値、月300時間到達が次の目標)。

私の37Designでは、2号機 (Ubuntu サーバー) で **OpenClaw** を継続運用しています。fork は `37designfk/openclaw` で、systemd user サービスとして port 18789 で常駐稼働中です。

「OpenClawって最近GitHub Star数が伸びてるけど、Claude Codeとは何が違うの?」「Claudeのサブスク料金で動くの?」「Banリスクは大丈夫?」——2026年5月時点で経営者・エンジニアの方から質問が急増しているテーマです。

この記事では、**自社forkを実運用している立場**から、OpenClawの実体・Claude Codeとの違い・Windows/Mac/Dockerインストール・Claudeサブスクとの組み合わせ・Banリスク対策まで体系的に解説します。日本語圏でこの粒度の解説記事はまだ存在しません。

> Claude Code / Hermes Agent / AIエージェントの全体像は[Claude Codeとは?経営者向け完全ガイド](/blog/claude-code-complete-guide-for-business-owners-2026/) / [Hermes Agentとは?完全ガイド](/blog/hermes-agent-complete-guide-for-business-2026/) / [AIエージェントとは?](/blog/ai-agent-complete-guide-for-sme-2026-business/) を併読してください。

---

## OpenClaw とは? - Claude Code互換のオープンソース AIエージェント

### OpenClaw の定義と読み方

**OpenClaw (オープンクロー)** は、Anthropic の Claude Code に**コマンド互換 + プロトコル互換**で動作する **完全オープンソース (OSS) のAIエージェント**です。

「Claude」(クロード) と「Claw」(爪、クロー) の言葉遊びで、**「Claudeの爪痕を残したOSS実装」**というニュアンスがあります。

### GitHub Star数と急成長

公式リポジトリ **github.com/openclaw/openclaw** は2026年5月時点で **GitHub Stars 約20万 (200K+)** に到達し、AIエージェント分野で世界トップクラスの注目を集めています。

### なぜ「Claude Code互換」なのか

OpenClawは内部実装が全く違うものの、Claude Code と以下の点で互換性を持ちます:

- **Skills 仕様**: Claude Code の Skills (繰り返し業務テンプレ) がそのまま動作
- **MCP (Model Context Protocol)**: 外部サービス連携の標準プロトコルをサポート
- **CLAUDE.md**: プロジェクト記憶ファイルを同様に解釈
- **Subscription連携**: Claude Pro / Max のサブスクトークンを使って実行可能

これにより、**Claude Code利用者がOpenClawに移植するコストが極めて低い**のが特徴です。

---

## OpenClaw と Claude Code の違い - 経営者目線で何を選ぶか

| 観点 | Claude Code | OpenClaw |
|---|---|---|
| ライセンス | 商用 (Anthropic) | **完全OSS (MIT等)** |
| 提供形態 | CLIツール (Anthropic配布) | **OSS / 自社サーバー導入可** |
| モデル | Claude (Anthropic専用) | **Claude / GPT / Gemini / ローカルLLM 切替可** |
| ブラウザ操作 | 限定的 | **browser relay でブラウザ完全制御** |
| 機密性 | Enterprise プランで担保 | **完全ローカル運用可** |
| 商用サポート | あり (Anthropic) | コミュニティベース |
| 公式日本語ドキュメント | あり | ほぼなし |

### 古田スタックの使い分け方針

正直な現状を書きます。

- **メイン: Claude Code** (週77時間業務運用、月300時間到達目標)
- **副系: OpenClaw** (2号機常駐、ブラウザ操作 / マルチモデル / ローカル運用 用途)
- **副系: Hermes Agent** (3号機PoC運用)

「乗り換える」のではなく「**Claude Codeでは難しい業務をOpenClaw / Hermesに逃がす**」三層構成です。

---

## OpenClaw でできること - 主要コンポーネント解説

OpenClawは内部的に複数のコンポーネントに分かれています。

### 1. OpenClaw Gateway

中核となるゲートウェイサービス。Claude / GPT / ローカルLLM 等の各モデルAPIを統一プロトコルで提供します。私の37Designでは2号機にsystemd userサービスとして常駐させ、port 18789 で待ち受けています。

### 2. Browser Relay (ブラウザ操作)

OpenClaw の代表的な強みが **Browser Relay** によるブラウザ操作機能。「ブラウザでログインしてフォーム入力 → ボタンクリック → 結果取得」のような操作を自然言語指示で完全自動化できます。Claude Codeでは難しい領域です。

### 3. OpenClaw Query

検索・データ取得用のクエリエンジン。Web検索 / DB照会 / 自社知識ベース検索を統一インターフェースで実行。

### 4. OpenClaw AI (AI機能のラッパー)

各種AIモデルへのプロンプト送信 / 結果取得を抽象化。Claude / GPT / ローカル を同じ書き方で扱える。

### 5. Skills 互換システム

Claude Code の Skills 仕様をそのまま読み込めるため、既存スキル資産を流用可能です。

---

## OpenClaw のインストール (Windows / Mac / Docker)

### Mac (Mac mini含む)

Macでは **Docker Desktop** または **OrbStack** 経由でのインストールが定番です。Mac mini M2/M4 は OpenClaw のローカルLLM運用 (Ollama 連携) の人気プラットフォームになっています。

```bash
# 公式 setup スクリプト
curl -fsSL https://openclaw.dev/install.sh | bash
```

### Windows

Windowsは **WSL2 (Windows Subsystem for Linux)** 経由が標準。Powershell単体での運用も技術的には可能ですが、コミュニティの主流はWSL2経由です。

### Linux / 自社サーバー (推奨)

私の37Designはこのパターン。2号機 (Ubuntu) に **systemd ユーザーサービス**として常駐させています:

```bash
systemctl --user start openclaw-gateway
systemctl --user enable openclaw-gateway
```

### Docker 経由

公式 Docker イメージも提供されており、コンテナ運用が可能です。ただし systemd user service 化が現在の推奨方式 (upstream の `scripts/docker/setup.sh` が systemd user service 化する仕様に変わっています)。

---

## OpenClaw を Claude サブスクで動かす - oauth / setup-token / Banリスク

### Claudeサブスクとの連携方法

OpenClaw は Claude Pro / Max のサブスクライントークンを使って動作可能です。連携方式は主に以下:

- **oauth**: ブラウザベースの認証フロー
- **setup-token**: トークンを手動セットアップ
- **API Key**: API直接利用 (Pro/Maxのトークンとは別)

### Claude Ban リスクと回避策 (重要)

ここは2026年5月時点で**最も質問が多いポイント**です。

Claude のサブスクライントークンを使って OpenClaw 等のサードパーティツールから大量リクエストを送ると、**Anthropic 側で異常検知され、アカウントが一時停止 (Ban) されるケース**が報告されています。

### 古田スタックの対策

- **Pro よりも Max ($100-200/月) を選ぶ**: 利用枠が大きく、異常検知の閾値に到達しにくい
- **OpenClaw の同時実行数を絞る**: Max でも並列セッションを過剰に動かさない
- **公式ガイドラインに従う**: Anthropic の利用規約 (ToS) を超える使い方をしない
- **業務本格運用は API 利用へ移行**: API は明示的に商用利用が許可されている

詳しい料金プランの考え方は[Claude料金プラン徹底比較【Pro/Max/Team/Enterprise/API】](/blog/claude-pricing-plans-complete-comparison-2026/)を参照してください。

---

## OpenClaw のセキュリティと運用上の注意

### 1. 設定ファイルの保護

OpenClawの設定ファイル `~/.openclaw/openclaw.json` には認証トークン等の機密情報が含まれます。**1Password等のパスワード管理 + 適切なファイル権限 (600)** を設定してください。

私の37Designでは、設定ファイルの正常サイズ (1900〜2200 byte) を監視し、何らかの原因で630 byteの最小スタブに書き換わった場合は自動でバックアップから書き戻すフックを入れています。

### 2. Gateway のポート公開

`openclaw-gateway` を port 18789 等で公開する際は、必ず **localhost (127.0.0.1) のみバインド** するか、firewall で外部アクセスを遮断してください。インターネット公開すると深刻な情報漏えいリスクがあります。

### 3. ローカルLLM選択時のリソース管理

Ollama 等のローカルLLMをOpenClaw経由で動かす場合、GPU / RAMの占有に注意。大規模モデルは Mac mini M4 (16GB) では動作困難な場合があります。

### 4. アップデート時の互換性確認

OpenClawは活発に開発されており、メジャーアップデートで設定ファイルや起動方式が変わることがあります。**本番運用前に staging 環境で必ず確認**してください。

---

## 古田スタックでのOpenClaw運用実例 (2026-05-18時点)

### 環境
- ハードウェア: 2号機 (Ubuntu / ASUS ROG Strix / RTX 3070 8GB)
- ソフトウェア: OpenClaw (fork: 37designfk/openclaw、main から再clone済)
- 常駐方式: systemd user service (`~/.config/systemd/user/openclaw-gateway.service`)
- ポート: 18789
- 接続モデル: OpenAI Codex + Ollama (ローカル) + Anthropic API

### 主要用途
- ブラウザ操作の自動化 (Claude Code が苦手な領域)
- マルチモデル比較ベンチマーク
- ローカルLLM (DeepSeek等) の業務評価
- Discord 通知連携 (`<@<userId>>` 形式必須)

### 運用ルール
- Claude Code (週77h運用) のメインタスクには絶対介入させない (リスク分離)
- 設定ファイルの定期バックアップ (`~/.openclaw/openclaw.json.bak.*`)
- 異常時の自動 fallback (旧config 書き戻し)

---

## OpenClaw に関するよくある質問

### OpenClaw は無料で使えますか?

ソフトウェア自体は完全無料 (OSS)。Claude / GPTサブスクや API利用料、ローカルLLM運用のためのGPU/サーバー費用は別途必要です。

### OpenClaw と Claude Code、どちらを使うべきですか?

**Claude Code が業務メイン、OpenClaw が補助**の構成がおすすめです。OpenClawは「Claude Codeでは難しい領域 (ブラウザ操作 / マルチモデル / 完全ローカル運用)」を担う副系として位置づけるのが現実的です。

### OpenClaw を会社で使う場合のリスクは?

Claudeサブスクライントークン経由で大量リクエストするとBanリスクがあるため、本格商用利用は **Anthropic API 直接利用** が安全です。OpenClawをAPI経由で動かす方法も公式にサポートされています。

### Mac mini で OpenClaw は動きますか?

動きます。Mac mini M2 Pro / M4 が OpenClaw + Ollama の運用プラットフォームとして人気です。ただし大規模ローカルLLM (70B+) を動かすには M4 Pro 以上 + 32GB RAM が現実的なライン。

### OpenClaw と Hermes Agent の違いは何ですか?

両方ともOSS AIエージェントですが、**Hermes は Nous Research の独自モデルとセットで提供される垂直統合型**、**OpenClaw は Claude Code互換のラッパー型**という違いがあります。詳細は[Hermes Agentとは?完全ガイド](/blog/hermes-agent-complete-guide-for-business-2026/)を参照してください。

### OpenClaw の日本語ドキュメントはありますか?

公式の日本語ドキュメントはほぼありません。本記事および私の運用メモが日本語圏では先行している部類です。

---

## まとめ - OpenClaw は「Claude Codeの隣に置く」が現役運用者の正解

OpenClawは2026年5月時点で **「Claude Code互換のOSSエージェント」**として完全に確立しました。GitHub Stars 200K超、活発な開発、Anthropic純正のClaude Codeを補完する役割で実用段階に入っています。

ただし、現役運用者の目線で **「Claude Code完全置き換え」は時期尚早**。私自身もメインは Claude Code (週77時間運用)、副系で OpenClaw (2号機常駐) + Hermes Agent (3号機PoC) という三層構成です。

経営者・エンジニアが今やるべき3アクション:

1. **github.com/openclaw/openclaw を確認** (公式リポジトリ + 200K Stars)
2. **2号機 (またはMac mini) でPoC運用を開始** (Docker + systemd user)
3. **Claude Code との使い分け方針を設計** (本格運用前のリスク分離が重要)

37Designでは、Claude Code / OpenClaw / Hermes Agent のハイブリッド構成設計を含む AI顧問サービスを提供しています。

[37Design への無料相談はこちら](/contact/)

[AI顧問サービスの詳細はこちら](/lp/ai-consulting/)

---

**関連記事**

- [Hermes Agentとは?Nous ResearchのOSS AIエージェント完全ガイド](/blog/hermes-agent-complete-guide-for-business-2026/)
- [Claude Codeとは?経営者・非エンジニア向け完全ガイド](/blog/claude-code-complete-guide-for-business-owners-2026/)
- [Claude(クロード)とは?中小企業経営者のためのClaude AI完全ガイド](/blog/claude-ai-complete-guide-sme-2026/)
- [AIエージェントとは?中小企業の業務自動化完全ガイド](/blog/ai-agent-complete-guide-for-sme-2026-business/)
