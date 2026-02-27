export interface FormHandlerOptions {
  formId: string;
  submitBtnId: string;
  successMsgId: string;
  webhookUrl: string;
  fieldExtractor: (fd: FormData) => Record<string, string>;
  defaultButtonText: string;
  enableValidation?: boolean;
  rateLimitKey?: string;
  honeypotId?: string;
  consentId?: string;
  startedAtId?: string;
  statusMsgId?: string;
  scrollToSuccess?: boolean;
  resetFormOnSuccess?: boolean;
  autoHideSuccess?: boolean;
  onSuccess?: () => void;
}

const MIN_FILL_TIME_MS = 4_000;
const RATE_LIMIT_MS = 60_000;
const SUCCESS_HIDE_MS = 5_000;

function readStorage(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStorage(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    // ignore
  }
}

export function initFormHandler(opts: FormHandlerOptions): void {
  const resetForm = opts.resetFormOnSuccess !== false;
  const autoHide = opts.autoHideSuccess !== false;

  document.addEventListener("DOMContentLoaded", () => {
    const form = document.getElementById(opts.formId) as HTMLFormElement | null;
    const submitBtn = document.getElementById(
      opts.submitBtnId,
    ) as HTMLButtonElement | null;
    const successMsg = document.getElementById(opts.successMsgId);
    const statusMsg = opts.statusMsgId
      ? document.getElementById(opts.statusMsgId)
      : null;
    const startedAtInput = opts.startedAtId
      ? (document.getElementById(opts.startedAtId) as HTMLInputElement | null)
      : null;
    const honeypotInput = opts.honeypotId
      ? (document.getElementById(opts.honeypotId) as HTMLInputElement | null)
      : null;
    const consentInput = opts.consentId
      ? (document.getElementById(opts.consentId) as HTMLInputElement | null)
      : null;

    if (!form || !submitBtn) return;

    const showStatus = (message: string, isError: boolean) => {
      if (!statusMsg) return;
      statusMsg.textContent = message;
      statusMsg.classList.remove("hidden", "text-red-600", "text-green-600");
      statusMsg.classList.add(isError ? "text-red-600" : "text-green-600");
    };

    if (startedAtInput) {
      startedAtInput.value = String(Date.now());
    }

    form.addEventListener("submit", async (e: Event) => {
      e.preventDefault();

      if (successMsg) successMsg.classList.add("hidden");

      if (opts.enableValidation) {
        if (consentInput && !consentInput.checked) {
          showStatus("プライバシーポリシーへの同意が必要です。", true);
          return;
        }
        if (honeypotInput && honeypotInput.value) {
          showStatus(
            "送信内容を確認できませんでした。時間をおいて再度お試しください。",
            true,
          );
          return;
        }
        const startedAt = Number(startedAtInput?.value || "0");
        if (!startedAt || Date.now() - startedAt < MIN_FILL_TIME_MS) {
          showStatus(
            "入力時間が短すぎます。内容をご確認のうえ再送信してください。",
            true,
          );
          return;
        }
        if (opts.rateLimitKey) {
          const lastSubmittedAt = Number(
            readStorage(opts.rateLimitKey) || "0",
          );
          if (Date.now() - lastSubmittedAt < RATE_LIMIT_MS) {
            showStatus(
              "連続送信を防ぐため、1分ほど待ってから再送信してください。",
              true,
            );
            return;
          }
        }
      }

      submitBtn.disabled = true;
      submitBtn.textContent = "送信中...";
      if (opts.enableValidation) showStatus("送信しています...", false);

      const formData = new FormData(form);
      const data = opts.fieldExtractor(formData);

      try {
        const response = await fetch(opts.webhookUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data),
        });

        if (response.ok) {
          if (resetForm) form.reset();
          if (opts.rateLimitKey)
            writeStorage(opts.rateLimitKey, String(Date.now()));
          if (startedAtInput) startedAtInput.value = String(Date.now());
          successMsg?.classList.remove("hidden");
          if (opts.enableValidation)
            showStatus("送信が完了しました。ありがとうございます。", false);
          if (opts.scrollToSuccess) {
            successMsg?.scrollIntoView({
              behavior: "smooth",
              block: "nearest",
            });
          }
          if (opts.onSuccess) opts.onSuccess();
          if (autoHide) {
            setTimeout(() => {
              successMsg?.classList.add("hidden");
            }, SUCCESS_HIDE_MS);
          }
        } else {
          if (opts.enableValidation) {
            showStatus(
              "送信に失敗しました。時間をおいてもう一度お試しください。",
              true,
            );
          } else {
            alert("送信に失敗しました。もう一度お試しください。");
          }
        }
      } catch (error) {
        console.error("Error:", error);
        if (opts.enableValidation) {
          showStatus(
            "通信エラーが発生しました。時間をおいて再度お試しください。",
            true,
          );
        } else {
          alert("送信に失敗しました。もう一度お試しください。");
        }
      } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = opts.defaultButtonText;
      }
    });
  });
}
