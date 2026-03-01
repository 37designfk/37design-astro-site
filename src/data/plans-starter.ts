import type { PlanStarter } from "./types";

export const plansStarter: PlanStarter[] = [
  {
    name: "スターターパック",
    subtitle: "まずは体感する",
    price: "30",
    unit: "万円〜",
    period: "初期費用",
    features: [
      "現状業務のヒアリング・分析",
      "自動化ツール1業務の導入",
      "操作マニュアル作成",
      "導入後2週間のサポート",
    ],
    cta: "このプランで相談する",
    popular: false,
  },
  {
    name: "スタンダードパック",
    subtitle: "本格的にDXを進める",
    price: "80",
    unit: "万円〜",
    period: "初期費用",
    features: [
      "業務フロー全体の分析・設計",
      "自動化ツール複数導入",
      "CRM（顧客管理）初期構築",
      "AIチャットボット導入",
      "社内研修（2回）",
      "導入後1ヶ月のサポート",
    ],
    cta: "このプランで相談する",
    popular: true,
  },
  {
    name: "フルパッケージ",
    subtitle: "会社全体をAI企業に",
    price: "要相談",
    unit: "",
    period: "",
    features: [
      "スタンダードの全内容",
      "全部門の業務自動化設計",
      "カスタムAIモデル構築",
      "外部システム連携",
      "社内研修（無制限）",
      "導入後3ヶ月の伴走サポート",
    ],
    cta: "まずは相談する",
    popular: false,
  },
];
