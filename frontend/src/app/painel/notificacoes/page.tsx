"use client";

import { useCallback, useEffect, useState } from "react";
import { Button, Card, Empty, ErrorMessage, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { addDays, formatDate, isoDate } from "@/lib/format";
import type { NotificationHistory } from "@/lib/types";

type Item = NotificationHistory["items"][number];
type Status = "all" | "unread" | "read";

const STATUS: [Status, string][] = [
  ["all", "Todas"],
  ["unread", "Não lidas"],
  ["read", "Lidas"],
];

const PAGE = 20;

function dayLabel(iso: string) {
  const day = iso.slice(0, 10);
  const today = isoDate();
  if (day === today) return "Hoje";
  if (day === addDays(today, -1)) return "Ontem";
  const text = new Date(day + "T12:00:00").toLocaleDateString("pt-BR", { weekday: "long", day: "2-digit", month: "long" });
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** Histórico de avisos: filtro por situação (todas, não lidas, lidas) e por dia/período; apagar o que já foi lido. */
export default function NotificationsPage() {
  const [status, setStatus] = useState<Status>("all");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [items, setItems] = useState<Item[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [unread, setUnread] = useState(0);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();
  const [notice, setNotice] = useState<string>();

  const load = useCallback(
    async (nextPage: number, reset: boolean) => {
      setLoading(true);
      setError(undefined);
      const q = new URLSearchParams({ status, page: String(nextPage), size: String(PAGE) });
      if (from) q.set("from", from);
      if (to) q.set("to", to);
      try {
        const data = await api.get<NotificationHistory>(`/api/notifications/history?${q}`);
        setItems((cur) => (reset ? data.items : [...cur, ...data.items]));
        setPage(nextPage);
        setHasMore(data.hasMore);
        setUnread(data.unread);
        setTotal(data.total);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    },
    [status, from, to],
  );

  useEffect(() => {
    load(0, true);
  }, [load]);

  function preset(days: number | "month" | "all") {
    const today = isoDate();
    if (days === "all") {
      setFrom("");
      setTo("");
    } else if (days === "month") {
      setFrom(today.slice(0, 8) + "01");
      setTo(today);
    } else {
      setFrom(addDays(today, -(days - 1)));
      setTo(today);
    }
  }

  async function markAllRead() {
    await api.post("/api/notifications/read").catch((e) => setError((e as Error).message));
    load(0, true);
  }

  async function clearRead() {
    if (!confirm("Apagar todas as notificações já lidas? Não dá para desfazer.")) return;
    try {
      const res = await api.post<{ deleted: number }>("/api/notifications/clear-read");
      setNotice(`${res.deleted} notificação(ões) apagada(s).`);
      load(0, true);
    } catch (e) {
      setError((e as Error).message);
    }
  }

  async function remove(n: Item) {
    try {
      await api.del(`/api/notifications/${n.id}`);
      setItems((cur) => cur.filter((x) => x.id !== n.id));
      setTotal((t) => Math.max(0, t - 1));
    } catch (e) {
      setError((e as Error).message);
    }
  }

  const groups: [string, Item[]][] = [];
  for (const n of items) {
    const label = dayLabel(n.createdAt);
    const last = groups[groups.length - 1];
    if (last && last[0] === label) last[1].push(n);
    else groups.push([label, [n]]);
  }

  const chip = (active: boolean) =>
    `rounded-full border px-3 py-1.5 text-sm font-bold ${active ? "border-transparent bg-brand text-white shadow-glow" : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"}`;
  const today = isoDate();

  return (
    <>
      <PageHeader title="Notificações">
        <Button variant="secondary" size="sm" onClick={markAllRead} disabled={unread === 0}>
          Marcar todas como lidas
        </Button>
        <Button variant="danger" size="sm" onClick={clearRead}>
          Apagar as lidas
        </Button>
      </PageHeader>

      <div className="mb-4 space-y-3">
        <div className="flex flex-wrap gap-2">
          {STATUS.map(([key, label]) => (
            <button key={key} onClick={() => setStatus(key)} className={chip(status === key)}>
              {key === "unread" && unread > 0 ? `${label} (${unread})` : label}
            </button>
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button onClick={() => preset("all")} className={chip(!from && !to)}>
            Todos os dias
          </button>
          <button onClick={() => preset(1)} className={chip(from === today && to === today)}>
            Hoje
          </button>
          <button onClick={() => preset(7)} className={chip(from === addDays(today, -6) && to === today)}>
            7 dias
          </button>
          <button onClick={() => preset("month")} className={chip(from === today.slice(0, 8) + "01" && to === today)}>
            Este mês
          </button>
          <span className="ml-1 text-sm text-zinc-500">ou escolha:</span>
          <input type="date" value={from} max={to || undefined} onChange={(e) => setFrom(e.target.value)} className="rounded-lg border border-zinc-300 px-2 py-1 text-sm" aria-label="De" />
          <span className="text-zinc-400">até</span>
          <input type="date" value={to} min={from || undefined} onChange={(e) => setTo(e.target.value)} className="rounded-lg border border-zinc-300 px-2 py-1 text-sm" aria-label="Até" />
        </div>
      </div>

      <ErrorMessage message={error} />
      {notice && <p className="mb-3 rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">{notice}</p>}

      {!loading && items.length === 0 ? (
        <Card>
          <Empty>
            {status === "unread"
              ? "Você não tem notificações novas."
              : from || to
                ? "Nenhuma notificação neste período."
                : "Quando um cliente agendar, cancelar ou remarcar, aparece aqui."}
          </Empty>
        </Card>
      ) : (
        <div className="space-y-5">
          {groups.map(([label, list]) => (
            <section key={label}>
              <h2 className="mb-2 text-sm font-bold text-zinc-500">{label}</h2>
              <ul className="space-y-2">
                {list.map((n) => (
                  <li key={n.id} className={`shadow-soft flex items-start gap-3 rounded-2xl p-4 ${n.read ? "bg-white" : "bg-[#FFF5F9] ring-1 ring-[#F9CFE0]"}`}>
                    <div className="min-w-0 flex-1">
                      <p className="flex items-center gap-2 font-bold">
                        {n.title}
                        {!n.read && <span className="bg-brand inline-block h-2.5 w-2.5 rounded-full" aria-label="não lida" />}
                      </p>
                      <p className="text-sm text-zinc-600">{n.message}</p>
                      <p className="mt-0.5 text-xs text-zinc-400">
                        {formatDate(n.createdAt)} {n.createdAt.slice(11, 16)}
                      </p>
                    </div>
                    {n.read && (
                      <Button variant="ghost" size="sm" onClick={() => remove(n)} aria-label="Apagar notificação">
                        Apagar
                      </Button>
                    )}
                  </li>
                ))}
              </ul>
            </section>
          ))}
          {hasMore && (
            <Button variant="secondary" className="w-full" disabled={loading} onClick={() => load(page + 1, false)}>
              {loading ? "Carregando..." : "Mostrar mais"}
            </Button>
          )}
          <p className="text-center text-xs text-zinc-500">
            {total} notificação(ões). As lidas há mais de 30 dias saem sozinhas; só dá para apagar as que já foram lidas.
          </p>
        </div>
      )}
    </>
  );
}
