"use client";

import { useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";

declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, options: Record<string, unknown>) => string;
      reset: (widgetId?: string) => void;
      remove: (widgetId?: string) => void;
    };
  }
}

const SCRIPT_SRC = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";

/**
 * Captcha do Cloudflare Turnstile. A chave pública vem do servidor (/api/public/config); sem chave, o captcha fica
 * desligado: `required` é false, nada aparece e os cadastros funcionam como antes.
 */
export function useTurnstile() {
  const [siteKey, setSiteKey] = useState<string>();
  const [token, setToken] = useState<string>();

  useEffect(() => {
    api
      .get<{ turnstileSiteKey?: string }>("/api/public/config")
      .then((c) => setSiteKey(c.turnstileSiteKey || ""))
      .catch(() => setSiteKey(""));
  }, []);

  return {
    siteKey,
    token,
    setToken,
    required: Boolean(siteKey),
    headers: token ? { "X-Turnstile-Token": token } : undefined,
  };
}

function loadScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (window.turnstile) return resolve();
    const found = document.querySelector<HTMLScriptElement>(`script[src="${SCRIPT_SRC}"]`);
    const script = found ?? Object.assign(document.createElement("script"), { src: SCRIPT_SRC, async: true, defer: true });
    script.addEventListener("load", () => resolve(), { once: true });
    script.addEventListener("error", () => reject(new Error("captcha")), { once: true });
    if (!found) document.head.appendChild(script);
  });
}

/** Mostra o captcha. `resetKey` muda para pedir um novo desafio (por exemplo, depois de um erro no envio). */
export function TurnstileWidget({
  siteKey,
  onToken,
  resetKey = 0,
}: {
  siteKey?: string;
  onToken: (token?: string) => void;
  resetKey?: number;
}) {
  const box = useRef<HTMLDivElement>(null);
  const widget = useRef<string>(undefined);
  const callback = useRef(onToken);
  callback.current = onToken;

  useEffect(() => {
    if (!siteKey || !box.current) return;
    let cancelled = false;
    loadScript()
      .then(() => {
        if (cancelled || !box.current || !window.turnstile) return;
        widget.current = window.turnstile.render(box.current, {
          sitekey: siteKey,
          callback: (t: string) => callback.current(t),
          "expired-callback": () => callback.current(undefined),
          "error-callback": () => callback.current(undefined),
        });
      })
      .catch(() => callback.current(undefined));
    return () => {
      cancelled = true;
      if (widget.current && window.turnstile) window.turnstile.remove(widget.current);
      widget.current = undefined;
    };
  }, [siteKey]);

  useEffect(() => {
    if (resetKey > 0 && widget.current && window.turnstile) window.turnstile.reset(widget.current);
  }, [resetKey]);

  if (!siteKey) return null;
  return <div ref={box} className="flex justify-center" />;
}
