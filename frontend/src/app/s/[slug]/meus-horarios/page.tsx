"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { AppPromo } from "@/components/InstallApp";
import { Icon } from "@/components/Icon";
import { Badge, ErrorMessage, Field } from "@/components/ui";
import { api } from "@/lib/api";
import { STATUS_COLOR, STATUS_LABEL, formatMoney, isoDate, shortDateTime } from "@/lib/format";
import type { Booking } from "@/lib/types";

const REMEMBER_KEY = "salao.meus-horarios";

/** "Meus horários": o cliente consulta com o mesmo nome e WhatsApp que usou ao agendar, sem precisar de link. */
export default function MyBookingsPage() {
  const { slug } = useParams<{ slug: string }>();
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [bookings, setBookings] = useState<Booking[] | null>(null);
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(REMEMBER_KEY) ?? "null");
      if (saved?.name) setName(saved.name);
      if (saved?.phone) setPhone(saved.phone);
    } catch {
      // sem armazenamento local: o cliente digita de novo
    }
  }, []);

  async function search(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(undefined);
    try {
      setBookings(await api.post<Booking[]>(`/api/public/salons/${slug}/my-bookings`, { name, phone }));
      try {
        localStorage.setItem(REMEMBER_KEY, JSON.stringify({ name, phone }));
      } catch {
        // ignora
      }
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const now = `${isoDate()}T${new Date().toTimeString().slice(0, 5)}`;
  const upcoming = (bookings ?? []).filter((b) => b.startAt >= now && b.status !== "CANCELED").reverse();
  const past = (bookings ?? []).filter((b) => !upcoming.includes(b));

  return (
    <main className="min-h-screen pb-16">
      <header className="bg-brand rounded-b-[2rem] px-4 pb-8 pt-8 text-white">
        <div className="mx-auto max-w-xl">
          <Link href={`/s/${slug}`} className="text-sm font-semibold text-white/80 hover:text-white">
            ‹ Voltar para o agendamento
          </Link>
          <h1 className="mt-3 text-2xl font-extrabold">Meus horários</h1>
          <p className="text-sm text-white/85">Digite o nome e o WhatsApp que você usou ao agendar.</p>
        </div>
      </header>

      <div className="mx-auto max-w-xl px-4">
        <form onSubmit={search} className="shadow-soft -mt-4 space-y-3 rounded-2xl bg-white p-4">
          <Field label="Nome" required autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} />
          <Field
            label="WhatsApp"
            required
            type="tel"
            inputMode="tel"
            autoComplete="tel"
            placeholder="(11) 99999-9999"
            minLength={10}
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
          />
          <ErrorMessage message={error} />
          <button disabled={busy} className="bg-brand shadow-glow w-full rounded-2xl py-3.5 font-extrabold text-white disabled:opacity-50">
            {busy ? "Buscando..." : "Ver meus horários"}
          </button>
        </form>

        {bookings && bookings.length === 0 && (
          <p className="mt-8 text-center text-sm text-brand-muted">
            Não encontramos agendamentos com esse nome e WhatsApp. Confira se digitou igual ao do agendamento.
          </p>
        )}
        {upcoming.length > 0 && <List title="Próximos" items={upcoming} slug={slug} />}
        {past.length > 0 && <List title="Anteriores" items={past} slug={slug} />}
        <AppPromo className="mt-10" />
      </div>
    </main>
  );
}

function List({ title, items, slug }: { title: string; items: Booking[]; slug: string }) {
  return (
    <section className="mt-7">
      <h2 className="mb-3 text-lg font-extrabold">{title}</h2>
      <div className="space-y-3">
        {items.map((b) => (
          <Link
            key={b.token}
            href={`/s/${slug}/agendamento/${b.token}`}
            className="shadow-soft flex items-center gap-4 rounded-2xl bg-white p-4 transition hover:ring-2 hover:ring-brand-pink/40"
          >
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-[#FFEAF2] text-brand-rose">
              <Icon name="calendar" />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate font-extrabold">{b.serviceName}</span>
              <span className="block text-sm text-brand-muted">{shortDateTime(b.startAt)}</span>
              <span className="block text-xs text-brand-muted">com {b.professionalName} · {formatMoney(b.price)}</span>
            </span>
            <span className="flex flex-col items-end gap-1">
              <Badge className={STATUS_COLOR[b.status]}>{STATUS_LABEL[b.status]}</Badge>
              {b.cancelable && <span className="text-xs font-bold text-brand-rose">Remarcar ›</span>}
            </span>
          </Link>
        ))}
      </div>
    </section>
  );
}
