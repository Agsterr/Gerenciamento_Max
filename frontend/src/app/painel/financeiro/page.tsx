"use client";

import { useState } from "react";
import { Button, Card, Empty, ErrorMessage, Field, PageHeader, Stat } from "@/components/ui";
import { api } from "@/lib/api";
import { formatDate, formatMoney, isoDate } from "@/lib/format";
import type { Expense, Ranking, Summary } from "@/lib/types";
import { useApi } from "@/lib/useApi";

const CATEGORIES = ["Aluguel", "Energia/Água", "Salários", "Produtos", "Marketing", "Impostos", "Outros"];

function monthStart() {
  const d = new Date();
  return isoDate(new Date(d.getFullYear(), d.getMonth(), 1));
}

export default function FinancePage() {
  const [from, setFrom] = useState(monthStart());
  const [to, setTo] = useState(isoDate());
  const { data: s, error, reload } = useApi<Summary>(`/api/reports/summary?from=${from}&to=${to}`);

  return (
    <>
      <PageHeader title="Financeiro">
        <input type="date" value={from} onChange={(e) => e.target.value && setFrom(e.target.value)} className="rounded-lg border border-zinc-300 px-2 py-1 text-sm" />
        <span className="text-zinc-400">até</span>
        <input type="date" value={to} onChange={(e) => e.target.value && setTo(e.target.value)} className="rounded-lg border border-zinc-300 px-2 py-1 text-sm" />
      </PageHeader>
      <ErrorMessage message={error} />

      {s && (
        <div className="space-y-6">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Stat label="Receita" value={formatMoney(s.totalRevenue)} hint={`Serviços ${formatMoney(s.servicesRevenue)} · Produtos ${formatMoney(s.productSalesRevenue)}`} />
            <Stat label="Custos" value={formatMoney(s.totalCosts)} />
            <Stat label="Lucro" value={formatMoney(s.profit)} hint={s.totalRevenue > 0 ? `Margem ${Math.round((s.profit / s.totalRevenue) * 100)}%` : undefined} />
            <Stat label="Ticket médio" value={formatMoney(s.averageTicket)} hint={`${s.appointmentsDone} atendimentos`} />
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <Card>
              <h2 className="mb-3 font-semibold">Composição dos custos</h2>
              <dl className="space-y-1.5 text-sm">
                {[
                  ["Comissões", s.commissions],
                  ["Material dos serviços", s.serviceMaterialCost],
                  ["Produtos usados/perdidos", s.productsUsedCost],
                  ["Custo dos produtos vendidos", s.productsSoldCost],
                  ["Despesas", s.expenses],
                ].map(([label, value]) => (
                  <div key={label as string} className="flex justify-between">
                    <dt className="text-zinc-600">{label}</dt>
                    <dd className="font-medium">{formatMoney(value as number)}</dd>
                  </div>
                ))}
              </dl>
            </Card>
            <Card>
              <h2 className="mb-3 font-semibold">Operação</h2>
              <dl className="space-y-1.5 text-sm">
                <Row label="Atendimentos finalizados" value={s.appointmentsDone} />
                <Row label="Agendamentos online" value={s.onlineBookings} />
                <Row label="Cancelados" value={s.appointmentsCanceled} />
                <Row label="Faltas" value={s.appointmentsNoShow} />
                <Row label="Tempo médio previsto" value={s.averageEstimatedMinutes != null ? `${Math.round(s.averageEstimatedMinutes)} min` : "—"} />
                <Row label="Tempo médio real" value={s.averageRealMinutes != null ? `${Math.round(s.averageRealMinutes)} min` : "—"} />
              </dl>
            </Card>
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <RankingCard title="Por profissional" rows={s.byProfessional} showCommission />
            <RankingCard title="Por serviço" rows={s.byService} />
          </div>

          {s.lowStock.length > 0 && (
            <Card className="border-rose-200 bg-rose-50">
              <h2 className="mb-2 font-semibold text-rose-800">Estoque baixo</h2>
              <ul className="text-sm text-rose-800">
                {s.lowStock.map((p) => (
                  <li key={p.id}>
                    {p.name}: {p.stock} {p.unit} (mínimo {p.minStock})
                  </li>
                ))}
              </ul>
            </Card>
          )}

          <Expenses from={from} to={to} onChange={reload} />
        </div>
      )}
    </>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between">
      <dt className="text-zinc-600">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}

function RankingCard({ title, rows, showCommission }: { title: string; rows: Ranking[]; showCommission?: boolean }) {
  return (
    <Card className="overflow-x-auto">
      <h2 className="mb-3 font-semibold">{title}</h2>
      {rows.length === 0 ? (
        <Empty>Sem atendimentos no período.</Empty>
      ) : (
        <table className="w-full text-sm">
          <thead className="text-left text-zinc-500">
            <tr>
              <th className="py-1 font-medium">Nome</th>
              <th className="py-1 font-medium">Qtd</th>
              <th className="py-1 font-medium">Receita</th>
              {showCommission && <th className="py-1 font-medium">Comissão</th>}
              <th className="py-1 font-medium">Tempo real</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.name} className="border-t border-zinc-100">
                <td className="py-1.5">{r.name}</td>
                <td>{r.count}</td>
                <td>{formatMoney(r.revenue)}</td>
                {showCommission && <td>{formatMoney(r.commission)}</td>}
                <td>{r.avgRealMinutes != null ? `${Math.round(r.avgRealMinutes)} min` : "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Card>
  );
}

function Expenses({ from, to, onChange }: { from: string; to: string; onChange: () => void }) {
  const { data, reload } = useApi<Expense[]>(`/api/expenses?from=${from}&to=${to}`);
  const [form, setForm] = useState({ description: "", category: CATEGORIES[0], amount: "", date: isoDate() });
  const [error, setError] = useState<string>();

  async function add(e: React.FormEvent) {
    e.preventDefault();
    setError(undefined);
    try {
      await api.post("/api/expenses", { ...form, amount: Number(form.amount) });
      setForm({ ...form, description: "", amount: "" });
      reload();
      onChange();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function remove(id: number) {
    if (!confirm("Excluir despesa?")) return;
    await api.del(`/api/expenses/${id}`);
    reload();
    onChange();
  }

  return (
    <Card>
      <h2 className="mb-3 font-semibold">Despesas</h2>
      <form onSubmit={add} className="mb-4 grid gap-2 sm:grid-cols-5 sm:items-end">
        <Field label="Descrição" className="sm:col-span-2" required value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
        <label className="block text-sm">
          <span className="mb-1 block font-medium text-zinc-700">Categoria</span>
          <select className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            {CATEGORIES.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </label>
        <Field label="Valor (R$)" type="number" step="0.01" min="0.01" required value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} />
        <div className="flex gap-2">
          <Field label="Data" type="date" required value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
          <Button className="self-end">+</Button>
        </div>
      </form>
      <ErrorMessage message={error} />
      {data && data.length === 0 && <Empty>Nenhuma despesa no período.</Empty>}
      <ul className="divide-y text-sm">
        {data?.map((e) => (
          <li key={e.id} className="flex items-center justify-between py-2">
            <span>
              {formatDate(e.date)} · {e.description} <span className="text-zinc-400">({e.category})</span>
            </span>
            <span className="flex items-center gap-2">
              <strong>{formatMoney(e.amount)}</strong>
              <Button variant="ghost" size="sm" onClick={() => remove(e.id)} aria-label="Excluir">
                ×
              </Button>
            </span>
          </li>
        ))}
      </ul>
    </Card>
  );
}
