import type { PlanAiConsultant } from "./types";

export const plansAiConsultant: PlanAiConsultant[] = [
  {
    name: "ライトプラン",
    description: "まずはAI活用を始めたい方に",
    price: "10",
    roi: "月10万円の投資で、平均月20万円相当の業務効率化",
    included: [
      "月2回のオンライン相談（各60分）",
      "チャットでの質問対応（営業日）",
      "AI活用のアドバイス・情報共有",
      "業務改善の方向性の提案",
    ],
    excluded: ["ツール導入の実作業", "社員向け研修"],
    recommended: false,
  },
  {
    name: "スタンダードプラン",
    description: "本格的にAI活用を進めたい方に",
    price: "15",
    roi: "月15万円の投資で、平均月40万円相当の業務効率化",
    included: [
      "週1回のオンライン相談（各60分）",
      "チャットでの質問対応（営業日）",
      "AI活用ロードマップの策定",
      "ツール選定・導入サポート",
      "プロンプト作成・業務テンプレート提供",
    ],
    excluded: ["社員向け研修"],
    recommended: true,
  },
  {
    name: "プレミアムプラン",
    description: "全社的にAI活用を推進したい方に",
    price: "30",
    roi: "月30万円の投資で、平均月100万円相当の業務効率化",
    included: [
      "週1回のオンライン相談（各60分）",
      "チャットでの質問対応（即日対応）",
      "AI活用ロードマップの策定",
      "ツール導入・設定の代行",
      "社員向けAI研修（月1回）",
      "月次レポート・効果測定",
    ],
    excluded: [],
    recommended: false,
  },
];
