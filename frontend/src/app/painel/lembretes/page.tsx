"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Badge, Button, Card, Empty, ErrorMessage, Field, PageHeader, Select } from "@/components/ui";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { REMINDER_MODES, formatPhone, shortDateTime } from "@/lib/format";
import type { Professional, ReminderItem, Reminders, StaffReminderRule, StaffReminderSettings } from "@/lib/types";
import { useApi } from "@/lib/useApi";

export default function RemindersPage() {
  return (
    <>
      <PageHeader title="Lembretes" />
      <div className="grid gap-4 lg:grid-cols-2">
        <CustomerReminders />
        <MyReminders />
      </div>
    </>
  );
}

/** Clientes de amanhã/depois de amanhã: abre o WhatsApp com a mensagem e o link de confirmação prontos. */
function CustomerReminders() {
  const { user } = useAuth();
  const { data, error, reload } = useApi<Reminders>("/api/reminders");
  const [actionError, setActionError] = useState<string>();

  async function send(item: ReminderItem) {
    window.open(item.whatsappUrl, "_blank", "noopener");
    setActionError(undefined);
    try {
      await api.post(`/api/reminders/${item.appointmentId}/sent`);
      reload();
    } catch (e) {
      setActionError((e as Error).message);
    }
  }

  const mode = REMINDER_MODES.find((m) => m.value === data?.mode)?.label;
  const byDay = (d: number) => data?.items.filter((i) => i.daysBefore === d) ?? [];

  return (
    <Card>
      <h2 className="font-extrabold">Clientes para confirmar</h2>
      <p className="mb-3 text-sm text-zinc-600">
        Lembrete: <strong>{mode ?? "..."}</strong>
        {user?.role === "OWNER" && (
          <>
            {" "}
            ·{" "}
            <Link href="/painel/configuracoes" className="text-brand-rose hover:underline">
              alterar
            </Link>
          </>
        )}
        . O cliente confirma pelo link (ou pelo app) e aparece como <strong>Confirmado</strong> na agenda.
      </p>
      <ErrorMessage message={error ?? actionError} />
      {data?.mode === "OFF" && <Empty>Lembrete desligado.</Empty>}
      {data && data.mode !== "OFF" && data.items.length === 0 && <Empty>Nenhum horário para lembrar.</Empty>}
      {data?.days.map((d) =>
        byDay(d).length ? (
          <div key={d} className="mb-4">
            <p className="mb-2 text-sm font-bold text-brand-muted">{d === 1 ? "Amanhã" : "Depois de amanhã"}</p>
            <ul className="divide-y divide-[#F6EEF3]">
              {byDay(d).map((i) => (
                <li key={i.appointmentId} className="flex items-center gap-3 py-2.5">
                  <div className="min-w-0 flex-1 text-sm">
                    <p className="font-bold">
                      {i.customerName}{" "}
                      {i.status === "CONFIRMED" ? (
                        <Badge className="bg-emerald-100 text-emerald-800">{i.customerConfirmed ? "Cliente confirmou" : "Confirmado"}</Badge>
                      ) : i.reminderSentAt ? (
                        <Badge className="bg-sky-100 text-sky-800">Lembrete enviado</Badge>
                      ) : null}
                    </p>
                    <p className="text-zinc-600">
                      {shortDateTime(i.startAt)} · {i.serviceName} com {i.professionalName}
                    </p>
                    <p className="text-xs text-zinc-400">{formatPhone(i.customerPhone)}</p>
                  </div>
                  {i.status !== "CONFIRMED" && (
                    <Button size="sm" variant={i.reminderSentAt ? "secondary" : "primary"} onClick={() => send(i)}>
                      {i.reminderSentAt ? "Reenviar" : "WhatsApp"}
                    </Button>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ) : null,
      )}
      <p className="text-xs text-zinc-500">Todo dia às 8h o sino avisa quantos clientes ainda faltam lembrar.</p>
    </Card>
  );
}

const PRESETS: { label: string; rule: StaffReminderRule }[] = [
  { label: "1 dia antes às 19h", rule: { daysBefore: 1, atTime: "19:00", minutesBefore: null } },
  { label: "No dia às 8h", rule: { daysBefore: 0, atTime: "08:00", minutesBefore: null } },
  { label: "2 horas antes", rule: { daysBefore: null, atTime: null, minutesBefore: 120 } },
  { label: "30 minutos antes", rule: { daysBefore: null, atTime: null, minutesBefore: 30 } },
];

/** Lembretes dos atendimentos para o próprio usuário: aparecem no sino (e no app de gestão). */
function MyReminders() {
  const { data, reload } = useApi<StaffReminderSettings>("/api/me/reminders");
  const { data: professionals } = useApi<Professional[]>("/api/professionals");
  const [form, setForm] = useState<StaffReminderSettings | null>(null);
  const [error, setError] = useState<string>();
  const [message, setMessage] = useState<string>();

  useEffect(() => {
    if (data) setForm({ professionalId: data.professionalId, rules: data.rules.map((r) => ({ ...r, atTime: r.atTime?.slice(0, 5) ?? null })) });
  }, [data]);

  if (!form) return <Card>Carregando...</Card>;

  const setRule = (i: number, rule: StaffReminderRule) => setForm({ ...form, rules: form.rules.map((r, k) => (k === i ? rule : r)) });

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form) return;
    setError(undefined);
    setMessage(undefined);
    try {
      await api.put("/api/me/reminders", form);
      setMessage("Salvo! Os avisos chegam no sino e no app Salão Max Gestão.");
      reload();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <Card>
      <h2 className="font-extrabold">Meus lembretes de atendimento</h2>
      <p className="mb-3 text-sm text-zinc-600">Escolha quando você quer ser avisado dos seus atendimentos (só você recebe).</p>
      <form onSubmit={save} className="space-y-3">
        <Select
          label="Agenda"
          value={form.professionalId ?? ""}
          onChange={(e) => setForm({ ...form, professionalId: e.target.value ? Number(e.target.value) : null })}
        >
          <option value="">Todos os profissionais</option>
          {professionals
            ?.filter((p) => p.active)
            .map((p) => (
              <option key={p.id} value={p.id}>
                Só {p.name}
              </option>
            ))}
        </Select>

        {form.rules.length === 0 && <p className="text-sm text-zinc-500">Nenhum lembrete. Adicione abaixo.</p>}
        {form.rules.map((r, i) => (
          <div key={i} className="flex flex-wrap items-end gap-2 rounded-xl bg-[#FFF5F9] p-3">
            <Select
              label="Tipo"
              className="w-40"
              value={r.minutesBefore !== null ? "min" : "day"}
              onChange={(e) =>
                setRule(i, e.target.value === "min" ? { daysBefore: null, atTime: null, minutesBefore: 60 } : { daysBefore: 1, atTime: "19:00", minutesBefore: null })
              }
            >
              <option value="day">Dias antes, às</option>
              <option value="min">Tempo antes</option>
            </Select>
            {r.minutesBefore !== null ? (
              <Select label="Antecedência" className="w-36" value={r.minutesBefore} onChange={(e) => setRule(i, { ...r, minutesBefore: Number(e.target.value) })}>
                {[15, 30, 45, 60, 90, 120, 180, 240, 360, 720].map((m) => (
                  <option key={m} value={m}>
                    {m < 60 ? `${m} min` : `${m / 60} h`}
                  </option>
                ))}
              </Select>
            ) : (
              <>
                <Select label="Dia" className="w-36" value={r.daysBefore ?? 1} onChange={(e) => setRule(i, { ...r, daysBefore: Number(e.target.value) })}>
                  <option value={0}>No próprio dia</option>
                  {[1, 2, 3, 7].map((d) => (
                    <option key={d} value={d}>
                      {d} dia{d > 1 ? "s" : ""} antes
                    </option>
                  ))}
                </Select>
                <Field label="Horário" type="time" className="w-28" required value={r.atTime ?? ""} onChange={(e) => setRule(i, { ...r, atTime: e.target.value })} />
              </>
            )}
            <Button type="button" size="sm" variant="ghost" onClick={() => setForm({ ...form, rules: form.rules.filter((_, k) => k !== i) })}>
              Remover
            </Button>
          </div>
        ))}
        {form.rules.length < 5 && (
          <div className="flex flex-wrap gap-2">
            {PRESETS.map((p) => (
              <button
                key={p.label}
                type="button"
                className="rounded-full border border-[#F1E3EB] px-3 py-1 text-sm font-semibold text-brand-muted hover:border-brand-rose hover:text-brand-rose"
                onClick={() => setForm({ ...form, rules: [...form.rules, p.rule] })}
              >
                + {p.label}
              </button>
            ))}
          </div>
        )}
        <ErrorMessage message={error} />
        {message && <p className="text-sm text-emerald-700">{message}</p>}
        <Button>Salvar meus lembretes</Button>
      </form>
    </Card>
  );
}
