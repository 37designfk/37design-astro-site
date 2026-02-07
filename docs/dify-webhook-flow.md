# Dify → n8n → Mautic 連携フロー

## n8n ワークフロー設定

### 1. Webhook受信ノード
- URL: `https://n8n-onprem.37d.jp/webhook/dify-lead`
- Method: POST
- 受信データ:
  ```json
  {
    "email": "user@example.com",
    "name": "山田太郎",
    "company": "株式会社サンプル",
    "message": "AIチャットボットからの問い合わせ"
  }
  ```

### 2. Mautic登録ノード
- Endpoint: `https://m6.37d.jp/api/contacts/new`
- カスタムフィールド:
  - `inquiry_type`: "chatbot"
  - `inquiry_source`: "dify"
  - `inquiry_message`: message

### 3. LINE通知ノード（オプション）
- LINE Notify API で担当者に通知
- メッセージ例: 「新しいチャット問い合わせがありました」

## Difyでのツール設定

### OpenAPI Schema
```yaml
openapi: 3.0.0
info:
  title: 37Design Lead Capture
  version: 1.0.0
paths:
  /webhook/dify-lead:
    post:
      summary: チャットからのリード登録
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                email:
                  type: string
                name:
                  type: string
                company:
                  type: string
                message:
                  type: string
      responses:
        '200':
          description: Success
```

### Difyプロンプトでのツール呼び出し
```
ユーザーが具体的な相談を希望し、連絡先を教えてくれた場合は、
`register_lead` ツールを使って情報を登録してください。

登録後は以下のメッセージを表示：
「ありがとうございます！担当者から24時間以内にご連絡いたします。
お急ぎの場合は [LINEでご連絡](https://jmp9xv65.autosns.app/line) ください。」
```
