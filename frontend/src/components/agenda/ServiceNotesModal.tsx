"use client";

import { useEffect, useState } from "react";
import { Button, ErrorMessage, Modal } from "@/components/ui";
import { api } from "@/lib/api";
import type { Appointment } from "@/lib/types";

export function ServiceNotesField({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <label className="block text-sm">
      <span className="mb-1 block font-semibold text-brand-ink">Anotações do atendimento</span>
      <textarea
        rows={3}
        maxLength={1000}
        placeholder="Ex.: tinta 7.1 + OX 20 vol, 35 min de pausa; corte em camadas, franja lateral"
        className="w-full rounded-xl border border-[#F1E3EB] bg-white px-3 py-2.5 outline-none focus:border-brand-rose focus:ring-4 focus:ring-brand-pink/15"
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
      <span className="text-xs text-zinc-500">Só a equipe do salão vê. Fica no histórico do cliente.</span>
    </label>
  );
}

/** Anotações internas do profissional (tinta usada, corte feito...). */
export function ServiceNotesModal({
  appointment,
  onClose,
  onSaved,
}: {
  appointment: Appointment | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [text, setText] = useState("");
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setText(appointment?.serviceNotes ?? "");
    setError(undefined);
  }, [appointment]);

  async function save() {
    if (!appointment) return;
    setBusy(true);
    try {
      await api.put(`/api/appointments/${appointment.id}/service-notes`, { serviceNotes: text });
      onSaved();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="Anotações" open={!!appointment} onClose={onClose}>
      {appointment && (
        <div className="space-y-4">
          <p className="text-sm text-zinc-600">
            {appointment.customer.name} · {appointment.service.name} com {appointment.professional.name}
          </p>
          <ServiceNotesField value={text} onChange={setText} />
          <ErrorMessage message={error} />
          <Button className="w-full" onClick={save} disabled={busy}>
            {busy ? "Salvando..." : "Salvar anotações"}
          </Button>
        </div>
      )}
    </Modal>
  );
}
