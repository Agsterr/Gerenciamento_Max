"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { AppPromo } from "@/components/InstallApp";
import { RescheduleBooking } from "@/components/booking/RescheduleBooking";
import { Badge, Button, Card, ErrorMessage } from "@/components/ui";
import { api } from "@/lib/api";
import { STATUS_COLOR, customerStatusLabel, formatMoney, formatTime, weekdayLabel } from "@/lib/format";
import type { Booking } from "@/lib/types";
import { useApi } from "@/lib/useApi";

export default function BookingPage() {
  const { slug, token } = useParams<{ slug: string; token: string }>();
  const path = `/api/public/salons/${slug}/bookings/${token}`;
  const { data: b, error, reload } = useApi<Booking>(path);
  const [actionError, setActionError] = useState<string>();
  const [rescheduling, setRescheduling] = useState(false);
  const [confirming, setConfirming] = useState(false);

  async function confirmPresence() {
    setActionError(undefined);
    setConfirming(true);
    try {
      await api.post(`${path}/confirm`);
      reload();
    } catch (e) {
      setActionError((e as Error).message);
    } finally {
      setConfirming(false);
    }
  }

  async function cancel() {
    if (!confirm("Cancelar este agendamento?")) return;
    setActionError(undefined);
    try {
      await api.post(`${path}/cancel`);
      reload();
    } catch (e) {
      setActionError((e as Error).message);
    }
  }

  if (error) return <p className="p-12 text-center text-zinc-500">Agendamento não encontrado.</p>;
  if (!b) return <p className="p-12 text-center text-zinc-500">Carregando...</p>;

  return (
    <main className="mx-auto max-w-md px-4 py-10">
      <Card className="p-6 text-center">
        {b.status !== "CANCELED" && <p className="text-4xl">✓</p>}
        <h1 className="mt-2 text-xl font-semibold">
          {b.status === "CANCELED" ? "Agendamento cancelado" : `Tudo certo, ${b.customerName.split(" ")[0]}!`}
        </h1>
        <div className="mt-4 space-y-1 text-zinc-700">
          <p className="font-medium">{b.serviceName}</p>
          <p>{weekdayLabel(b.startAt.slice(0, 10))}</p>
          <p className="text-2xl font-semibold">{formatTime(b.startAt)}</p>
          <p className="text-sm">com {b.professionalName}</p>
          <p className="text-sm">{formatMoney(b.price)}</p>
          <Badge className={STATUS_COLOR[b.status]}>{customerStatusLabel(b.status, b.salonConfirmed)}</Badge>
        </div>
        {rescheduling ? (
          <RescheduleBooking
            slug={slug}
            booking={b}
            onCancel={() => setRescheduling(false)}
            onDone={() => {
              setRescheduling(false);
              reload();
            }}
          />
        ) : (
          <p className="mt-6 text-xs text-zinc-500">
            Para ver seus horários depois, use <strong>Meus horários</strong> com seu nome e WhatsApp.
            {b.status !== "CANCELED" && !b.cancelable && " Mudanças com menos de 2h de antecedência só pelo salão."}
          </p>
        )}
        <ErrorMessage message={actionError} />
        <div className="mt-4 flex flex-col gap-2">
          {b.confirmable && !rescheduling && (
            <Button onClick={confirmPresence} disabled={confirming} className="py-3 text-lg">
              {confirming ? "Confirmando..." : "Confirmar presença"}
            </Button>
          )}
          {b.status === "CONFIRMED" && <p className="font-bold text-emerald-700">Presença confirmada. Até lá!</p>}
          {b.cancelable && !rescheduling && (
            <>
              <Button variant={b.confirmable ? "secondary" : "primary"} onClick={() => setRescheduling(true)}>
                Remarcar horário
              </Button>
              <Button variant="danger" onClick={cancel}>
                Cancelar agendamento
              </Button>
            </>
          )}
          <Link href={`/s/${slug}/meus-horarios`} className="text-sm font-semibold text-brand-rose hover:underline">
            Meus horários
          </Link>
          <Link href={`/s/${slug}`} className="text-sm text-brand-rose hover:underline">
            Fazer outro agendamento
          </Link>
        </div>
      </Card>
      <AppPromo className="mt-6" />
    </main>
  );
}
