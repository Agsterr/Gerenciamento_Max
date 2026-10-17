"use client";

import { useEffect, useState } from "react";
import { Button, Card, ErrorMessage, Field, NewPasswordFields, PageHeader, Select } from "@/components/ui";
import { api, appDownloadUrl } from "@/lib/api";
import { WeeklyHoursEditor, normalizeHours } from "@/components/WeeklyHoursEditor";
import type { Role, Salon, User } from "@/lib/types";
import { useApi } from "@/lib/useApi";

export default function SettingsPage() {
  const { data: salon, reload } = useApi<Salon>("/api/salon");
  const [form, setForm] = useState<Salon | null>(null);
  const [message, setMessage] = useState<string>();
  const [error, setError] = useState<string>();
  const [origin, setOrigin] = useState("");

  useEffect(() => setOrigin(window.location.origin), []);
  useEffect(() => {
    if (salon) setForm({ ...salon, hours: normalizeHours(salon.hours) });
  }, [salon]);

  if (!form) return <p className="text-zinc-500">Carregando...</p>;

  const publicUrl = `${origin}/s/${form.slug}`;

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form) return;
    setError(undefined);
    setMessage(undefined);
    try {
      await api.put("/api/salon", {
        name: form.name,
        phone: form.phone,
        address: form.address,
        hours: form.hours,
        slotMinutes: Number(form.slotMinutes),
      });
      setMessage("Salvo!");
      reload();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <>
      <PageHeader title="Configurações" />
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <h2 className="mb-1 font-semibold">Link de agendamento online</h2>
          <p className="mb-3 text-sm text-zinc-600">Compartilhe no Instagram, WhatsApp e Google.</p>
          <div className="flex gap-2">
            <input readOnly value={publicUrl} className="flex-1 rounded-lg border border-zinc-300 bg-zinc-50 px-3 py-2 text-sm" />
            <Button variant="secondary" onClick={() => navigator.clipboard.writeText(publicUrl)}>
              Copiar
            </Button>
          </div>
          <a href={publicUrl} target="_blank" rel="noreferrer" className="mt-2 inline-block text-sm text-brand-rose hover:underline">
            Abrir página do cliente →
          </a>
        </Card>

        <AppsCard publicUrl={publicUrl} salonName={form.name} />

        <Card>
          <h2 className="mb-3 font-extrabold">Dados e horário de funcionamento</h2>
          <form onSubmit={save} className="space-y-3">
            <Field label="Nome do salão" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            <Field label="Telefone" value={form.phone ?? ""} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            <Field label="Endereço" value={form.address ?? ""} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            <div className="pt-2">
              <p className="mb-2 font-bold text-brand-ink">Horário de funcionamento</p>
              <WeeklyHoursEditor value={form.hours} onChange={(hours) => setForm({ ...form, hours })} />
            </div>
            <Select label="Intervalo entre horários na agenda" value={form.slotMinutes} onChange={(e) => setForm({ ...form, slotMinutes: Number(e.target.value) })}>
              {[10, 15, 20, 30, 45, 60].map((m) => (
                <option key={m} value={m}>
                  {m} min
                </option>
              ))}
            </Select>
            <ErrorMessage message={error} />
            {message && <p className="text-sm text-emerald-700">{message}</p>}
            <Button className="w-full sm:w-auto" disabled={form.hours.length === 0}>Salvar</Button>
          </form>
        </Card>

        <Team />

        <Card>
          <h2 className="mb-1 font-semibold">Conta</h2>
          <p className="mb-3 text-sm text-zinc-600">
            Excluir a conta remove seu acesso. Se você for o último dono, o salão e todos os dados são apagados.
          </p>
          <a href="/excluir-conta" className="text-sm font-medium text-brand-rose hover:underline">
            Excluir conta →
          </a>
        </Card>
      </div>
    </>
  );
}

function Team() {
  const { data: users, reload } = useApi<User[]>("/api/users");
  const [form, setForm] = useState({ name: "", email: "", password: "", role: "STAFF" as Role });
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string>();

  async function add(e: React.FormEvent) {
    e.preventDefault();
    setError(undefined);
    if (form.password !== confirm) return setError("As senhas não conferem.");
    try {
      await api.post("/api/users", form);
      setForm({ name: "", email: "", password: "", role: "STAFF" });
      setConfirm("");
      reload();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <Card>
      <h2 className="mb-1 font-semibold">Acessos ao painel</h2>
      <p className="mb-3 text-sm text-zinc-600">Funcionários veem agenda, clientes e produtos; o financeiro é só do dono.</p>
      <ul className="mb-4 divide-y text-sm">
        {users?.map((u) => (
          <li key={u.id} className="flex justify-between py-1.5">
            <span>
              {u.name} <span className="text-zinc-400">{u.email}</span>
            </span>
            <span className="text-zinc-500">{u.role === "OWNER" ? "Dono" : "Funcionário"}</span>
          </li>
        ))}
      </ul>
      <form onSubmit={add} className="grid gap-2 sm:grid-cols-2">
        <Field label="Nome" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        <Field label="E-mail" type="email" required value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
        <NewPasswordFields
          value={form.password}
          onChange={(password) => setForm({ ...form, password })}
          confirm={confirm}
          onConfirmChange={setConfirm}
        />
        <Select label="Perfil" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value as Role })}>
          <option value="STAFF">Funcionário</option>
          <option value="OWNER">Dono</option>
        </Select>
        <ErrorMessage message={error} />
        <Button className="sm:col-span-2">Adicionar acesso</Button>
      </form>
    </Card>
  );
}

/** Links dos apps: gestão (mesmo login do painel) e cliente (entra com nome e WhatsApp). */
function AppsCard({ publicUrl, salonName }: { publicUrl: string; salonName: string }) {
  const [copied, setCopied] = useState(false);
  const message =
    `Agende seu horário no ${salonName} pelo link: ${publicUrl}\n` +
    `Ou pelo app Salão Max (Android): ${appDownloadUrl("cliente")}\n` +
    `Para ver, remarcar ou cancelar, é só entrar com seu nome e WhatsApp.`;
  return (
    <Card>
      <h2 className="mb-1 font-semibold">Apps no celular (Android)</h2>
      <div className="mt-3 space-y-4 text-sm">
        <div>
          <p className="font-bold text-brand-ink">Salão Max Gestão — para você e a equipe</p>
          <p className="text-zinc-600">Entre com o mesmo e-mail e senha deste painel.</p>
          <a href={appDownloadUrl("gestao")} className="mt-1 inline-block font-bold text-brand-rose hover:underline">
            Baixar app do salão →
          </a>
        </div>
        <div>
          <p className="font-bold text-brand-ink">Salão Max — para seus clientes</p>
          <p className="text-zinc-600">O cliente entra com o nome e o WhatsApp que usou ao agendar, sem senha.</p>
          <div className="mt-1 flex flex-wrap gap-3">
            <a href={appDownloadUrl("cliente")} className="font-bold text-brand-rose hover:underline">
              Baixar app do cliente →
            </a>
            <button
              type="button"
              className="font-bold text-emerald-700 hover:underline"
              onClick={() => {
                navigator.clipboard.writeText(message);
                setCopied(true);
              }}
            >
              {copied ? "Mensagem copiada!" : "Copiar mensagem para clientes"}
            </button>
          </div>
        </div>
      </div>
    </Card>
  );
}
