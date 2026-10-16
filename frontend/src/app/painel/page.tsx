"use client";

import { useState } from "react";
import { AppointmentCard } from "@/components/agenda/AppointmentCard";
import { FinishModal } from "@/components/agenda/FinishModal";
import { NewAppointmentModal } from "@/components/agenda/NewAppointmentModal";
import { Button, Card, Empty, ErrorMessage, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { addDays, formatMoney, isoDate, weekdayLabel } from "@/lib/format";
import type { Appointment, Professional } from "@/lib/types";
import { useApi } from "@/lib/useApi";

export default function AgendaPage() {
  const [date, setDate] = useState(isoDate());
  const [creating, setCreating] = useState(false);
  const [finishing, setFinishing] = useState<Appointment | null>(null);
  const [actionError, setActionError] = useState<string>();
  const { data: appointments, error, reload } = useApi<Appointment[]>(`/api/appointments?from=${date}`);
  const { data: professionals } = useApi<Professional[]>("/api/professionals");

  async function act(a: Appointment, action: string) {
    if (action === "finish") return setFinishing(a);
    if (action === "cancel" && !confirm(`Cancelar o horário de ${a.customer.name}?`)) return;
    setActionError(undefined);
    try {
      await api.post(`/api/appointments/${a.id}/${action}`);
      reload();
    } catch (e) {
      setActionError((e as Error).message);
    }
  }

  const list = appointments ?? [];
  const active = list.filter((a) => a.status !== "CANCELED" && a.status !== "NO_SHOW");
  const columns = (professionals ?? [])
    .filter((p) => p.active || list.some((a) => a.professional.id === p.id))
    .map((p) => ({ professional: p, items: list.filter((a) => a.professional.id === p.id) }));

  return (
    <>
      <PageHeader title="Agenda">
        <Button variant="secondary" size="sm" onClick={() => setDate(addDays(date, -1))} aria-label="Dia anterior">
          ‹
        </Button>
        <input
          type="date"
          value={date}
          onChange={(e) => e.target.value && setDate(e.target.value)}
          className="rounded-lg border border-zinc-300 px-2 py-1 text-sm"
        />
        <Button variant="secondary" size="sm" onClick={() => setDate(addDays(date, 1))} aria-label="Próximo dia">
          ›
        </Button>
        <Button variant="ghost" size="sm" onClick={() => setDate(isoDate())}>
          Hoje
        </Button>
        <Button onClick={() => setCreating(true)}>+ Agendar</Button>
      </PageHeader>

      <p className="mb-4 text-zinc-600">
        {weekdayLabel(date)} · {active.length} atendimento(s) · previsto {formatMoney(active.reduce((s, a) => s + a.price, 0))}
      </p>

      <ErrorMessage message={error ?? actionError} />

      {columns.length === 0 ? (
        <Card>
          <Empty>Cadastre profissionais e serviços para começar a agendar.</Empty>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {columns.map(({ professional, items }) => (
            <section key={professional.id}>
              <h2 className="mb-2 font-semibold text-zinc-800">{professional.name}</h2>
              <div className="space-y-2">
                {items.length === 0 && <p className="text-sm text-zinc-400">Livre o dia todo</p>}
                {items.map((a) => (
                  <AppointmentCard key={a.id} appointment={a} onAction={(action) => act(a, action)} />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

      <NewAppointmentModal
        open={creating}
        date={date}
        onClose={() => setCreating(false)}
        onCreated={() => {
          setCreating(false);
          reload();
        }}
      />
      <FinishModal
        appointment={finishing}
        onClose={() => setFinishing(null)}
        onFinished={() => {
          setFinishing(null);
          reload();
        }}
      />
    </>
  );
}
