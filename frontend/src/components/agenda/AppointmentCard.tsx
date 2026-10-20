"use client";

import { Badge, Button } from "@/components/ui";
import { STATUS_COLOR, STATUS_LABEL, formatMoney, formatPhone, formatTime, shortDateTime, whatsappLink } from "@/lib/format";
import type { Appointment } from "@/lib/types";

export type AppointmentAction = "confirm" | "start" | "finish" | "cancel" | "no-show" | "reschedule" | "notes";

export function AppointmentCard({
  appointment: a,
  onAction,
}: {
  appointment: Appointment;
  onAction: (action: AppointmentAction) => void;
}) {
  const open = a.status === "SCHEDULED" || a.status === "CONFIRMED";
  const faded = a.status === "CANCELED" || a.status === "NO_SHOW";

  return (
    <div className={`rounded-xl border border-zinc-200 bg-white p-3 shadow-sm ${faded ? "opacity-60" : ""}`}>
      <div className="flex items-start justify-between gap-2">
        <div>
          <p className="text-sm font-semibold text-zinc-900">
            {formatTime(a.startAt)}–{formatTime(a.endAt)} · {a.service.name}
          </p>
          <p className="text-sm text-zinc-700">{a.customer.name}</p>
          <a
            href={whatsappLink(
              a.customerPhone,
              open ? `Olá, ${a.customer.name.split(" ")[0]}! Passando para lembrar do seu horário de ${a.service.name} ${shortDateTime(a.startAt)}.` : undefined,
            )}
            target="_blank"
            rel="noreferrer"
            className="text-xs text-emerald-700 hover:underline"
          >
            {formatPhone(a.customerPhone)} (WhatsApp)
          </a>
        </div>
        <div className="text-right">
          <Badge className={STATUS_COLOR[a.status]}>{STATUS_LABEL[a.status]}</Badge>
          <p className="mt-1 text-sm font-medium">{formatMoney(a.price)}</p>
          {a.customerConfirmedAt && <p className="text-xs font-bold text-emerald-700">✓ cliente confirmou</p>}
          {!a.customerConfirmedAt && a.reminderSentAt && <p className="text-xs text-sky-700">lembrete enviado</p>}
          {a.source === "ONLINE" && <p className="text-xs text-zinc-400">online</p>}
        </div>
      </div>

      {a.notes && <p className="mt-2 text-xs text-zinc-500">“{a.notes}”</p>}
      {a.serviceNotes && (
        <p className="mt-2 whitespace-pre-line rounded-lg bg-amber-50 px-2 py-1.5 text-xs text-amber-900">
          <span className="font-bold">Anotações:</span> {a.serviceNotes}
        </p>
      )}
      {a.status === "DONE" && a.realMinutes != null && (
        <p className="mt-2 text-xs text-zinc-500">
          Tempo real {a.realMinutes} min (previsto {a.estimatedMinutes} min)
        </p>
      )}

      {(open || a.status === "IN_PROGRESS") && (
        <div className="mt-3 flex flex-wrap gap-1.5">
          {a.status === "SCHEDULED" && (
            <Button size="sm" variant="secondary" onClick={() => onAction("confirm")}>
              Confirmar
            </Button>
          )}
          {open && (
            <Button size="sm" variant="secondary" onClick={() => onAction("start")}>
              Iniciar
            </Button>
          )}
          <Button size="sm" onClick={() => onAction("finish")}>
            Finalizar
          </Button>
          {open && (
            <>
              <Button size="sm" variant="secondary" onClick={() => onAction("reschedule")}>
                Remarcar
              </Button>
              <Button size="sm" variant="ghost" onClick={() => onAction("no-show")}>
                Faltou
              </Button>
              <Button size="sm" variant="danger" onClick={() => onAction("cancel")}>
                Cancelar
              </Button>
            </>
          )}
        </div>
      )}
      {a.status !== "CANCELED" && (
        <button onClick={() => onAction("notes")} className="mt-2 text-xs font-semibold text-brand-rose hover:underline">
          {a.serviceNotes ? "Editar anotações" : "+ Anotações (tinta, corte...)"}
        </button>
      )}
    </div>
  );
}
