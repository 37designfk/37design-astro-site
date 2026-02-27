// Server-side constants (frontmatter / layout / build-time scripts)

export const WEBHOOK_URLS = {
  aiDiagnosis: "https://n8n-onprem.37d.jp/webhook/ai-diagnosis",
} as const;

export const EXTERNAL_LINKS = {
  line: "https://jmp9xv65.autosns.app/line",
  phone: "tel:080-2412-2556",
} as const;

export const FORM_CONSTANTS = {
  rateLimitMs: 60_000,
  minFillTimeMs: 4_000,
  successHideMs: 5_000,
} as const;
