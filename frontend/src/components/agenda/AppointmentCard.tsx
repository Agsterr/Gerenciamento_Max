"use client";

import { Badge, Button } from "@/components/ui";
import { STATUS_COLOR, STATUS_LABEL, formatMoney, formatPhone, formatTime } from "@/lib/format";
import type { Appointment } from "@/lib/types";

export function AppointmentCard({
  appointment: a,
  onAction,
}: {
  appointment: Appointment;
  onAction: (action: "confirm" | "start" | "finish" | "cancel" | "no-show") => void;
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
            href={`https://wa.me/55${a.customerPhone}`}
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
          {a.source === "ONLINE" && <p className="text-xs text-zinc-400">online</p>}
        </div>
      </div>

      {a.notes && <p className="mt-2 text-xs text-zinc-500">“{a.notes}”</p>}
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
    </div>
  );
}
