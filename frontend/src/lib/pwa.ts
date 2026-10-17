"use client";

import { useEffect, useState } from "react";

/** Evento do Chrome/Android que permite mostrar o "Instalar app" no momento certo. */
type InstallPromptEvent = Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: string }> };

let deferred: InstallPromptEvent | null = null;
const listeners = new Set<() => void>();
const notify = () => listeners.forEach((l) => l());

/** Registra o service worker e guarda o pedido de instalação (chamado uma vez no layout raiz). */
export function setupPwa() {
  if (typeof window === "undefined") return;
  if ("serviceWorker" in navigator && process.env.NODE_ENV === "production") {
    navigator.serviceWorker.register("/sw.js").catch(() => undefined);
  }
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault();
    deferred = e as InstallPromptEvent;
    notify();
  });
  window.addEventListener("appinstalled", () => {
    deferred = null;
    notify();
  });
}

const isIos = () => /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
const isAndroid = () => /android/i.test(navigator.userAgent);
const isStandalone = () =>
  window.matchMedia("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone === true;

/** Estado para o botão "Instalar app": Android/Chrome instala direto; iPhone precisa do menu Compartilhar. */
export function useInstallApp() {
  const [state, setState] = useState({ canInstall: false, ios: false, android: false, installed: false });

  useEffect(() => {
    const update = () => setState({ canInstall: deferred !== null, ios: isIos(), android: isAndroid(), installed: isStandalone() });
    update();
    listeners.add(update);
    return () => {
      listeners.delete(update);
    };
  }, []);

  async function install() {
    if (!deferred) return;
    await deferred.prompt();
    await deferred.userChoice.catch(() => undefined);
    deferred = null;
    notify();
  }

  return { ...state, install };
}
