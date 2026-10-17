"use client";

import { useEffect, useState } from "react";
import { SlotPicker } from "@/components/agenda/SlotPicker";
import { TimeSelect } from "@/components/TimeSelect";
import { Button, ErrorMessage, Field, Modal, Select } from "@/components/ui";
import { api } from "@/lib/api";
import { shortDateTime, whatsappLink } from "@/lib/format";
import type { Appointment, Professional, Slot } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Salão remarca: novo dia, horário e (opcional) profissional; depois oferece avisar o cliente no WhatsApp. */
export function RescheduleModal({
  appointment: a,
  onClose,
  onSaved,
}: {
  appointment: Appointment | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [professionalId, setProfessionalId] = useState("");
  const [date, setDate] = useState("");
  const [time, setTime] = useState<string | null>(null);
  const [manual, setManual] = useState(false);
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<Appointment | null>(null);
  const { data: professionals } = useApi<Professional[]>(a ? "/api/professionals" : null);
  const { data: slots, loading } = useApi<Slot[]>(
    a && date && !manual
      ? `/api/appointments/availability?serviceId=${a.service.id}&date=${date}&professionalId=${professionalId || a.professional.id}`
      : null,
  );

  useEffect(() => {
    if (a) {
      setProfessionalId(String(a.professional.id));
      setDate(a.startAt.slice(0, 10));
      setManual(false);
      setError(undefined);
      setDone(null);
    }
  }, [a]);
  useEffect(() => setTime(null), [professionalId, date, manual]);

  async function save() {
    if (!a || !time) return;
    setBusy(true);
    setError(undefined);
    try {
      const updated = await api.put<Appointment>(`/api/appointments/${a.id}`, {
        customerId: a.customer.id,
        serviceId: a.service.id,
        professionalId: Number(professionalId),
        startAt: `${date}T${time}:00`,
        notes: a.notes,
        durationMinutes: a.estimatedMinutes,
        force: manual,
      });
      setDone(updated);
      onSaved();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="Remarcar horário" open={!!a} onClose={onClose}>
      {a && done ? (
        <div className="space-y-4 text-center">
          <p className="text-4xl">✓</p>
          <p>
            Remarcado para <strong>{shortDateTime(done.startAt)}</strong> com {done.professional.name}.
          </p>
          <a
            href={whatsappLink(
              a.customerPhone,
              `Olá, ${a.customer.name.split(" ")[0]}! Seu horário de ${a.service.name} foi remarcado para ${shortDateTime(done.startAt)} com ${done.professional.name}. Qualquer dúvida é só responder aqui.`,
            )}
            target="_blank"
            rel="noreferrer"
            className="block rounded-xl bg-emerald-600 px-4 py-2.5 font-bold text-white hover:bg-emerald-700"
          >
            Avisar no WhatsApp
          </a>
          <Button variant="ghost" onClick={onClose}>
            Fechar
          </Button>
        </div>
      ) : (
        a && (
          <div className="space-y-4">
            <p className="text-sm text-zinc-600">
              {a.customer.name} · {a.service.name} · hoje marcado {shortDateTime(a.startAt)}
            </p>
            <div className="grid grid-cols-2 gap-3">
              <Select label="Profissional" value={professionalId} onChange={(e) => setProfessionalId(e.target.value)}>
                {professionals
                  ?.filter((p) => p.active || p.id === a.professional.id)
                  .map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
              </Select>
              <Field label="Data" type="date" value={date} onChange={(e) => e.target.value && setDate(e.target.value)} />
            </div>
            <label className="flex items-center gap-2 text-sm text-zinc-700">
              <input type="checkbox" checked={manual} onChange={(e) => setManual(e.target.checked)} />
              Encaixe — qualquer horário, mesmo com conflito
            </label>
            {manual ? (
              <TimeSelect label="Horário" value={time} onChange={setTime} />
            ) : (
              <SlotPicker slots={slots} loading={loading} value={time} onChange={setTime} />
            )}
            <ErrorMessage message={error} />
            <Button className="w-full" disabled={!time || busy} onClick={save}>
              {busy ? "Salvando..." : time ? `Remarcar para ${time}` : "Escolha um horário"}
            </Button>
          </div>
        )
      )}
    </Modal>
  );
}
