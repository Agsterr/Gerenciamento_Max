"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { Badge, Button, Card, ErrorMessage } from "@/components/ui";
import { api } from "@/lib/api";
import { STATUS_COLOR, STATUS_LABEL, formatMoney, formatTime, weekdayLabel } from "@/lib/format";
import type { Booking } from "@/lib/types";
import { useApi } from "@/lib/useApi";

export default function BookingPage() {
  const { slug, token } = useParams<{ slug: string; token: string }>();
  const path = `/api/public/salons/${slug}/bookings/${token}`;
  const { data: b, error, reload } = useApi<Booking>(path);
  const [actionError, setActionError] = useState<string>();

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
          <Badge className={STATUS_COLOR[b.status]}>{STATUS_LABEL[b.status]}</Badge>
        </div>
        <p className="mt-6 text-xs text-zinc-500">Salve este link para consultar ou cancelar seu horário.</p>
        <ErrorMessage message={actionError} />
        <div className="mt-4 flex flex-col gap-2">
          {b.cancelable && (
            <Button variant="danger" onClick={cancel}>
              Cancelar agendamento
            </Button>
          )}
          <Link href={`/s/${slug}`} className="text-sm text-brand-rose hover:underline">
            Fazer outro agendamento
          </Link>
        </div>
      </Card>
    </main>
  );
}
