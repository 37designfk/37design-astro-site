# LP制作ルール

## 構成（13セクション）
1. ファーストビュー（キャッチコピー + CTA）
2. 問題提起
3. 共感
4. 解決策の提示
5. 商品/サービス紹介
6. 特徴・ベネフィット
7. 使い方・流れ
8. お客様の声
9. 比較・差別化
10. 料金
11. よくある質問
12. 最終CTA
13. フッター

## ファイル配置
- `src/pages/lp/{slug}.astro`
- LPLayout.astro を使用
- コンポーネント: `src/components/lp/` から import

## デザインルール
- モバイルファースト
- CTAボタン: bg-orange-500 hover:bg-orange-600, 大きく, 最低3箇所
- フォント: Noto Sans JP
- 既存コンポーネント（src/components/lp/）を最大限再利用

## ABテスト対応
- GrowthBook SDKでフィーチャーフラグ分岐可能な構造
- テスト対象要素にはdata-testid属性を付与
- バリアントBはsrc/components/lp/variants/に配置

## LP一覧（予定）
| LP | パス | ターゲット |
|----|------|-----------|
| LP自動生成サービス | /lp/lp-auto-generation | Web担当者、小規模事業主 |
| AI自動化コンサル | /lp/ai-automation-consulting | 中小企業経営者 |
| マーケティングOS | /lp/marketing-os | マーケ担当者、Web制作会社 |
| AI顧問サービス | /lp/ai-advisory | 経営者、CTO |
