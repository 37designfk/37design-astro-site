import type { PlanAiConsultant } from "./types";

export const plansAiConsultant: PlanAiConsultant[] = [
  {
    name: "月1回プラン",
    description: "まずはAI活用を始めたい方に",
    price: "2",
    roi: "月2万円の投資で、平均月10万円相当の業務効率化",
    included: [
      "月1回のオンライン相談（各30〜60分）",
      "チャットでの質問対応（営業日）",
      "AI活用のアドバイス・情報共有",
      "業務改善の方向性の提案",
    ],
    excluded: ["ツール導入の実作業", "社員向け研修"],
    recommended: true,
  },
  {
    name: "月2回プラン",
    description: "本格的にAI活用を進めたい方に",
    price: "4",
    roi: "月4万円の投資で、平均月20万円相当の業務効率化",
    included: [
      "月2回のオンライン相談（各30〜60分）",
      "チャットでの質問対応（営業日）",
      "AI活用ロードマップの策定",
      "ツール選定・導入サポート",
      "プロンプト作成・業務テンプレート提供",
    ],
    excluded: ["社員向け研修"],
    recommended: false,
  },
  {
    name: "月4回プラン",
    description: "全社的にAI活用を推進したい方に",
    price: "8",
    roi: "月8万円の投資で、平均月40万円相当の業務効率化",
    included: [
      "月4回のオンライン相談（各30〜60分）",
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
