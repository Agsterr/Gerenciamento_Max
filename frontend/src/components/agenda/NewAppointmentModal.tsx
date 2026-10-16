"use client";

import { useEffect, useState } from "react";
import { SlotPicker } from "@/components/agenda/SlotPicker";
import { Button, ErrorMessage, Field, Modal, Select } from "@/components/ui";
import { api } from "@/lib/api";
import { formatMoney, formatPhone } from "@/lib/format";
import type { Customer, Professional, Service, Slot } from "@/lib/types";
import { useApi } from "@/lib/useApi";

export function NewAppointmentModal({
  open,
  date: initialDate,
  onClose,
  onCreated,
}: {
  open: boolean;
  date: string;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [query, setQuery] = useState("");
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [newCustomer, setNewCustomer] = useState({ name: "", phone: "" });
  const [serviceId, setServiceId] = useState("");
  const [professionalId, setProfessionalId] = useState("");
  const [date, setDate] = useState(initialDate);
  const [time, setTime] = useState<string | null>(null);
  const [manual, setManual] = useState(false);
  const [duration, setDuration] = useState("");
  const [force, setForce] = useState(false);
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  const { data: services } = useApi<Service[]>(open ? "/api/services" : null);
  const { data: professionals } = useApi<Professional[]>(open ? "/api/professionals" : null);
  const { data: customers } = useApi<Customer[]>(
    open && query.length >= 2 && !customer ? `/api/customers?q=${encodeURIComponent(query)}` : null,
  );
  const slotsPath =
    open && serviceId && !manual
      ? `/api/appointments/availability?serviceId=${serviceId}&date=${date}` +
        (professionalId ? `&professionalId=${professionalId}` : "")
      : null;
  const { data: slots, loading: loadingSlots } = useApi<Slot[]>(slotsPath);

  useEffect(() => {
    if (open) {
      setDate(initialDate);
      setTime(null);
      setError(undefined);
    }
  }, [open, initialDate]);

  useEffect(() => {
    if (!manual) setTime(null);
  }, [serviceId, professionalId, date, manual]);

  const selectedService = services?.find((s) => String(s.id) === serviceId);

  function reset() {
    setQuery("");
    setCustomer(null);
    setNewCustomer({ name: "", phone: "" });
    setServiceId("");
    setProfessionalId("");
    setNotes("");
    setManual(false);
    setDuration("");
    setForce(false);
  }

  async function submit() {
    if (!time || !serviceId) return;
    setBusy(true);
    setError(undefined);
    try {
      const c =
        customer ??
        (await api.post<Customer>("/api/customers", { name: newCustomer.name, phone: newCustomer.phone }));
      await api.post("/api/appointments", {
        customerId: c.id,
        serviceId: Number(serviceId),
        professionalId: professionalId ? Number(professionalId) : null,
        startAt: `${date}T${time}:00`,
        notes: notes || null,
        durationMinutes: manual && duration ? Number(duration) : null,
        force: manual && force,
      });
      reset();
      onCreated();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const hasCustomer = customer || (newCustomer.name && newCustomer.phone.replace(/\D/g, "").length >= 10);

  return (
    <Modal title="Novo agendamento" open={open} onClose={onClose}>
      <div className="space-y-4">
        {customer ? (
          <div className="flex items-center justify-between rounded-lg bg-zinc-50 px-3 py-2">
            <div>
              <p className="font-medium">{customer.name}</p>
              <p className="text-xs text-zinc-500">{formatPhone(customer.phone)}</p>
            </div>
            <Button variant="ghost" size="sm" onClick={() => setCustomer(null)}>
              Trocar
            </Button>
          </div>
        ) : (
          <div>
            <Field
              label="Cliente (nome ou telefone)"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setNewCustomer((n) => ({ ...n, name: e.target.value }));
              }}
              placeholder="Buscar..."
            />
            {customers && customers.length > 0 && (
              <ul className="mt-1 divide-y rounded-lg border border-zinc-200">
                {customers.slice(0, 5).map((c) => (
                  <li key={c.id}>
                    <button
                      type="button"
                      className="w-full px-3 py-2 text-left text-sm hover:bg-zinc-50"
                      onClick={() => setCustomer(c)}
                    >
                      {c.name} · <span className="text-zinc-500">{formatPhone(c.phone)}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {query.length >= 2 && (
              <div className="mt-2 rounded-lg border border-dashed border-zinc-300 p-3">
                <p className="mb-2 text-xs text-zinc-500">Ou cadastre um novo cliente:</p>
                <Field
                  label="Telefone"
                  value={newCustomer.phone}
                  onChange={(e) => setNewCustomer((n) => ({ ...n, phone: e.target.value }))}
                  placeholder="(11) 99999-9999"
                  inputMode="tel"
                />
              </div>
            )}
          </div>
        )}

        <Select label="Serviço" value={serviceId} onChange={(e) => setServiceId(e.target.value)}>
          <option value="">Selecione...</option>
          {services
            ?.filter((s) => s.active)
            .map((s) => (
              <option key={s.id} value={s.id}>
                {s.name} · {s.durationMinutes} min · {formatMoney(s.price)}
              </option>
            ))}
        </Select>

        <div className="grid grid-cols-2 gap-3">
          <Select label="Profissional" value={professionalId} onChange={(e) => setProfessionalId(e.target.value)}>
            <option value="">Qualquer um</option>
            {professionals
              ?.filter((p) => p.active)
              .map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
          </Select>
          <Field label="Data" type="date" value={date} onChange={(e) => e.target.value && setDate(e.target.value)} />
        </div>

        {serviceId && (
          <div>
            <div className="mb-2 inline-flex rounded-lg border border-zinc-300 p-0.5 text-sm">
              {[
                [false, "Horários livres"],
                [true, "Manual"],
              ].map(([value, label]) => (
                <button
                  type="button"
                  key={String(value)}
                  onClick={() => {
                    setManual(value as boolean);
                    setTime(null);
                  }}
                  className={`rounded-md px-3 py-1 ${manual === value ? "bg-rose-600 text-white" : "text-zinc-600"}`}
                >
                  {label as string}
                </button>
              ))}
            </div>
            {manual ? (
              <div className="space-y-2">
                <div className="grid grid-cols-2 gap-3">
                  <Field label="Horário" type="time" value={time ?? ""} onChange={(e) => setTime(e.target.value || null)} />
                  <Field
                    label="Duração (min)"
                    type="number"
                    min={5}
                    max={720}
                    placeholder={String(selectedService?.durationMinutes ?? "")}
                    value={duration}
                    onChange={(e) => setDuration(e.target.value)}
                  />
                </div>
                <label className="flex items-start gap-2 text-sm text-zinc-700">
                  <input type="checkbox" className="mt-1" checked={force} onChange={(e) => setForce(e.target.checked)} />
                  <span>
                    Encaixe — marcar mesmo com conflito ou fora do expediente
                    {force && !professionalId && <span className="block text-xs text-rose-600">Escolha o profissional.</span>}
                  </span>
                </label>
              </div>
            ) : (
              <SlotPicker slots={slots} loading={loadingSlots} value={time} onChange={setTime} />
            )}
          </div>
        )}

        <Field label="Observações" value={notes} onChange={(e) => setNotes(e.target.value)} />
        <ErrorMessage message={error} />
        <Button className="w-full" disabled={!hasCustomer || !time || busy || (manual && force && !professionalId)} onClick={submit}>
          {busy ? "Salvando..." : time ? `Agendar às ${time}` : "Escolha um horário"}
        </Button>
      </div>
    </Modal>
  );
}
