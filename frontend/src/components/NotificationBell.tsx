"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";
import { formatDateTime } from "@/lib/format";
import type { Inbox } from "@/lib/types";

const POLL_MS = 60_000;

/** Sininho do painel: agendamentos, cancelamentos e remarcações feitos pelos clientes. */
export function NotificationBell() {
  const [inbox, setInbox] = useState<Inbox>();
  const [open, setOpen] = useState(false);
  const lastSeen = useRef<number | null>(null);

  const load = useCallback(async () => {
    try {
      const data = await api.get<Inbox>("/api/notifications");
      const newest = data.items[0]?.id ?? 0;
      // aviso do navegador só para o que chegou depois que o painel abriu
      if (lastSeen.current !== null && "Notification" in window && Notification.permission === "granted") {
        data.items
          .filter((n) => n.id > lastSeen.current! && !n.read)
          .forEach((n) => new Notification(n.title, { body: n.message, icon: "/icon-gestao.png", tag: `n${n.id}` }));
      }
      lastSeen.current = Math.max(lastSeen.current ?? 0, newest);
      setInbox(data);
    } catch {
      // sem rede: tenta no próximo ciclo
    }
  }, []);

  useEffect(() => {
    load();
    const t = setInterval(() => document.visibilityState === "visible" && load(), POLL_MS);
    const onFocus = () => load();
    window.addEventListener("focus", onFocus);
    return () => {
      clearInterval(t);
      window.removeEventListener("focus", onFocus);
    };
  }, [load]);

  async function toggle() {
    const next = !open;
    setOpen(next);
    if (next && "Notification" in window && Notification.permission === "default") {
      Notification.requestPermission().catch(() => undefined);
    }
    if (!next && inbox?.unread) {
      await api.post("/api/notifications/read").catch(() => undefined);
      load();
    }
  }

  const unread = inbox?.unread ?? 0;
  return (
    <div className="relative">
      <button
        onClick={toggle}
        aria-label={unread ? `${unread} notificações novas` : "Notificações"}
        className="relative rounded-xl p-2 text-brand-muted hover:bg-[#FFF1F6] hover:text-brand-rose"
      >
        <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
          <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0" />
        </svg>
        {unread > 0 && (
          <span className="bg-brand absolute -right-0.5 -top-0.5 min-w-5 rounded-full px-1 text-center text-xs font-extrabold leading-5 text-white">
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={toggle} />
          <div className="shadow-soft absolute right-0 z-50 mt-2 w-[min(22rem,calc(100vw-2rem))] overflow-hidden rounded-2xl border border-[#F1E3EB] bg-white md:left-0 md:right-auto">
            <p className="border-b border-[#F1E3EB] px-4 py-3 font-extrabold">Notificações</p>
            <ul className="max-h-96 divide-y divide-[#F6EEF3] overflow-y-auto">
              {inbox?.items.length === 0 && <li className="px-4 py-6 text-center text-sm text-zinc-500">Nada por aqui ainda.</li>}
              {inbox?.items.map((n) => (
                <li key={n.id} className={`px-4 py-3 text-sm ${n.read ? "" : "bg-[#FFF5F9]"}`}>
                  <p className="font-bold">{n.title}</p>
                  <p className="text-zinc-600">{n.message}</p>
                  <p className="mt-0.5 text-xs text-zinc-400">{formatDateTime(n.createdAt)}</p>
                </li>
              ))}
            </ul>
          </div>
        </>
      )}
    </div>
  );
}
