"use client";

import { useEffect, useState } from "react";
import { Button, Card, ErrorMessage, Field, PageHeader, Select } from "@/components/ui";
import { api } from "@/lib/api";
import { WEEKDAYS } from "@/lib/format";
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
    if (salon) setForm({ ...salon, openTime: salon.openTime.slice(0, 5), closeTime: salon.closeTime.slice(0, 5) });
  }, [salon]);

  if (!form) return <p className="text-zinc-500">Carregando...</p>;

  const days = form.workDays.split(",").filter(Boolean);
  const toggleDay = (d: string) => {
    const next = days.includes(d) ? days.filter((x) => x !== d) : [...days, d];
    setForm({ ...form, workDays: next.sort().join(",") });
  };
  const publicUrl = `${origin}/s/${form.slug}`;

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form) return;
    setError(undefined);
    setMessage(undefined);
    try {
      await api.put("/api/salon", { ...form, slotMinutes: Number(form.slotMinutes) });
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

        <Card>
          <h2 className="mb-3 font-semibold">Dados e horário de funcionamento</h2>
          <form onSubmit={save} className="space-y-3">
            <Field label="Nome do salão" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            <Field label="Telefone" value={form.phone ?? ""} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            <Field label="Endereço" value={form.address ?? ""} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            <div className="grid grid-cols-3 gap-3">
              <Field label="Abre" type="time" required value={form.openTime} onChange={(e) => setForm({ ...form, openTime: e.target.value })} />
              <Field label="Fecha" type="time" required value={form.closeTime} onChange={(e) => setForm({ ...form, closeTime: e.target.value })} />
              <Select label="Intervalo" value={form.slotMinutes} onChange={(e) => setForm({ ...form, slotMinutes: Number(e.target.value) })}>
                {[10, 15, 20, 30, 45, 60].map((m) => (
                  <option key={m} value={m}>
                    {m} min
                  </option>
                ))}
              </Select>
            </div>
            <div>
              <p className="mb-1 text-sm font-medium text-zinc-700">Dias de funcionamento</p>
              <div className="flex flex-wrap gap-1.5">
                {WEEKDAYS.map((d) => (
                  <button
                    type="button"
                    key={d.value}
                    onClick={() => toggleDay(d.value)}
                    className={`rounded-lg border px-3 py-1.5 text-sm ${
                      days.includes(d.value) ? "border-brand-rose bg-brand-rose text-white" : "border-zinc-300 bg-white"
                    }`}
                  >
                    {d.label}
                  </button>
                ))}
              </div>
            </div>
            <ErrorMessage message={error} />
            {message && <p className="text-sm text-emerald-700">{message}</p>}
            <Button>Salvar</Button>
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
  const [error, setError] = useState<string>();

  async function add(e: React.FormEvent) {
    e.preventDefault();
    setError(undefined);
    try {
      await api.post("/api/users", form);
      setForm({ name: "", email: "", password: "", role: "STAFF" });
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
        <Field label="Senha" type="password" minLength={6} required value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} />
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
