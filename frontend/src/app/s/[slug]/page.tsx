"use client";

import { useParams, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { SlotPicker } from "@/components/agenda/SlotPicker";
import { Button, Card, ErrorMessage, Field } from "@/components/ui";
import { api } from "@/lib/api";
import { addDays, formatMoney, isoDate } from "@/lib/format";
import type { Booking, PublicSalon, Slot } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Versão do cliente: escolhe serviço → profissional → dia/horário → nome e telefone. */
export default function PublicBookingPage() {
  const { slug } = useParams<{ slug: string }>();
  const router = useRouter();
  const base = `/api/public/salons/${slug}`;
  const { data: salon, error: salonError } = useApi<PublicSalon>(base);

  const [serviceId, setServiceId] = useState<number | null>(null);
  const [professionalId, setProfessionalId] = useState<number | null>(null);
  const [date, setDate] = useState<string | null>(null);
  const [time, setTime] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  const days = useMemo(() => {
    if (!salon) return [];
    const work = salon.workDays.split(",");
    const today = isoDate();
    return Array.from({ length: 21 }, (_, i) => addDays(today, i))
      .filter((d) => work.includes(String(((new Date(d + "T12:00:00").getDay() + 6) % 7) + 1)))
      .slice(0, 14);
  }, [salon]);

  useEffect(() => {
    if (!date && days.length) setDate(days[0]);
  }, [days, date]);
  useEffect(() => setTime(null), [serviceId, professionalId, date]);

  const slotsPath =
    serviceId && date
      ? `${base}/availability?serviceId=${serviceId}&date=${date}` + (professionalId ? `&professionalId=${professionalId}` : "")
      : null;
  const { data: slots, loading } = useApi<Slot[]>(slotsPath);

  if (salonError) return <Centered>Salão não encontrado.</Centered>;
  if (!salon) return <Centered>Carregando...</Centered>;

  const service = salon.services.find((s) => s.id === serviceId);

  async function book(e: React.FormEvent) {
    e.preventDefault();
    if (!serviceId || !date || !time) return;
    setBusy(true);
    setError(undefined);
    try {
      const res = await api.post<Booking>(`${base}/bookings`, {
        serviceId,
        professionalId,
        startAt: `${date}T${time}:00`,
        name,
        phone,
      });
      router.push(`/s/${slug}/agendamento/${res.token}`);
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto max-w-xl px-4 py-8">
      <header className="mb-6 text-center">
        <h1 className="text-2xl font-bold text-zinc-900">{salon.name}</h1>
        {salon.address && <p className="text-sm text-zinc-500">{salon.address}</p>}
        <p className="mt-1 text-sm text-zinc-500">Agende seu horário online</p>
      </header>

      <Step n={1} title="Escolha o serviço">
        <div className="space-y-2">
          {salon.services.map((s) => (
            <button
              key={s.id}
              onClick={() => setServiceId(s.id)}
              className={`flex w-full items-center justify-between rounded-xl border p-3 text-left ${
                serviceId === s.id ? "border-rose-600 bg-rose-50" : "border-zinc-200 bg-white hover:border-rose-300"
              }`}
            >
              <span>
                <span className="block font-medium">{s.name}</span>
                <span className="text-sm text-zinc-500">{s.durationMinutes} min</span>
              </span>
              <span className="font-semibold">{formatMoney(s.price)}</span>
            </button>
          ))}
          {salon.services.length === 0 && <p className="text-sm text-zinc-500">Nenhum serviço disponível no momento.</p>}
        </div>
      </Step>

      {service && (
        <Step n={2} title="Profissional">
          <div className="flex flex-wrap gap-2">
            {[{ id: null, name: "Sem preferência" }, ...salon.professionals].map((p) => (
              <Chip key={p.id ?? 0} active={professionalId === p.id} onClick={() => setProfessionalId(p.id)}>
                {p.name}
              </Chip>
            ))}
          </div>
        </Step>
      )}

      {service && (
        <Step n={3} title="Dia e horário">
          <div className="mb-3 flex gap-2 overflow-x-auto pb-1">
            {days.map((d) => {
              const dt = new Date(d + "T12:00:00");
              return (
                <button
                  key={d}
                  onClick={() => setDate(d)}
                  className={`min-w-14 rounded-xl border px-2 py-2 text-center ${
                    date === d ? "border-rose-600 bg-rose-600 text-white" : "border-zinc-200 bg-white"
                  }`}
                >
                  <span className="block text-xs capitalize">{dt.toLocaleDateString("pt-BR", { weekday: "short" })}</span>
                  <span className="block text-lg font-semibold">{dt.getDate()}</span>
                </button>
              );
            })}
          </div>
          <SlotPicker slots={slots} loading={loading} value={time} onChange={setTime} />
        </Step>
      )}

      {time && (
        <Step n={4} title="Seus dados">
          <form onSubmit={book} className="space-y-3">
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
            <p className="text-xs text-zinc-500">
              Ao agendar você concorda com a{" "}
              <a href="/privacidade" className="underline">
                Política de Privacidade
              </a>
              .
            </p>
            <ErrorMessage message={error} />
            <Button className="w-full py-3" disabled={busy}>
              {busy ? "Agendando..." : `Confirmar ${service?.name} às ${time}`}
            </Button>
          </form>
        </Step>
      )}
    </main>
  );
}

function Step({ n, title, children }: { n: number; title: string; children: React.ReactNode }) {
  return (
    <Card className="mb-4">
      <h2 className="mb-3 flex items-center gap-2 font-semibold">
        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-rose-600 text-xs text-white">{n}</span>
        {title}
      </h2>
      {children}
    </Card>
  );
}

function Chip({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={`rounded-full border px-4 py-1.5 text-sm ${active ? "border-rose-600 bg-rose-600 text-white" : "border-zinc-300 bg-white"}`}
    >
      {children}
    </button>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return <p className="p-12 text-center text-zinc-500">{children}</p>;
}
