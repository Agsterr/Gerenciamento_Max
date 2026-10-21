"use client";

import { useState } from "react";
import { Button, Card, Empty, ErrorMessage, Field, PageHeader, Stat } from "@/components/ui";
import { api } from "@/lib/api";
import { formatDate, formatMoney, isoDate } from "@/lib/format";
import type { Expense, ProductReport, Ranking, Summary } from "@/lib/types";
import { useApi } from "@/lib/useApi";

const FIXED = ["Aluguel", "Água", "Luz", "Internet e telefone", "Salários", "Contador", "Sistemas e assinaturas"];
const VARIABLE = ["Produtos e materiais", "Cortesias (café, água, lanches)", "Marketing", "Manutenção", "Impostos e taxas", "Outros"];

function monthStart(offset = 0) {
  const d = new Date();
  return isoDate(new Date(d.getFullYear(), d.getMonth() + offset, 1));
}

function monthEnd(offset = 0) {
  const d = new Date();
  return isoDate(new Date(d.getFullYear(), d.getMonth() + offset + 1, 0));
}

const PRESETS: [string, () => [string, string]][] = [
  ["Este mês", () => [monthStart(), isoDate()]],
  ["Mês passado", () => [monthStart(-1), monthEnd(-1)]],
  ["Últimos 7 dias", () => [isoDate(new Date(Date.now() - 6 * 86400000)), isoDate()]],
];

export default function FinancePage() {
  const [from, setFrom] = useState(monthStart());
  const [to, setTo] = useState(isoDate());
  const { data: s, error, reload } = useApi<Summary>(`/api/reports/summary?from=${from}&to=${to}`);

  return (
    <>
      <PageHeader title="Financeiro e relatórios">
        <div className="flex flex-wrap items-center gap-2 print:hidden">
          {PRESETS.map(([label, range]) => (
            <Button
              key={label}
              variant="secondary"
              size="sm"
              onClick={() => {
                const [f, t] = range();
                setFrom(f);
                setTo(t);
              }}
            >
              {label}
            </Button>
          ))}
          <input type="date" value={from} onChange={(e) => e.target.value && setFrom(e.target.value)} className="rounded-lg border border-zinc-300 px-2 py-1 text-sm" />
          <span className="text-zinc-400">até</span>
          <input type="date" value={to} onChange={(e) => e.target.value && setTo(e.target.value)} className="rounded-lg border border-zinc-300 px-2 py-1 text-sm" />
          <Button variant="secondary" size="sm" onClick={() => window.print()}>
            Imprimir / PDF
          </Button>
        </div>
      </PageHeader>
      <p className="-mt-2 mb-4 hidden text-sm text-zinc-500 print:block">
        Período: {formatDate(from)} a {formatDate(to)}
      </p>
      <ErrorMessage message={error} />

      {s && (
        <div className="space-y-6">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Stat label="Receita" value={formatMoney(s.totalRevenue)} hint={`Serviços ${formatMoney(s.servicesRevenue)} · Produtos ${formatMoney(s.productSalesRevenue)}`} />
            <Stat label="Custos e despesas" value={formatMoney(s.totalCosts)} hint={`Fixas ${formatMoney(s.fixedExpenses)} · Variáveis ${formatMoney(s.variableExpenses)}`} />
            <Stat label="Lucro" value={formatMoney(s.profit)} hint={s.totalRevenue > 0 ? `Margem ${Math.round((s.profit / s.totalRevenue) * 100)}%` : undefined} />
            <Stat label="Ticket médio" value={formatMoney(s.averageTicket)} hint={`${s.appointmentsDone - s.rework.count} atendimentos pagos`} />
          </div>

          <Statement s={s} />

          <div className="grid gap-4 lg:grid-cols-2">
            <ReworkCard s={s} />
            <Card>
              <h2 className="mb-3 font-semibold">Operação</h2>
              <dl className="space-y-1.5 text-sm">
                <Row label="Atendimentos finalizados" value={s.appointmentsDone} />
                <Row label="Refações (sem cobrança)" value={s.rework.count} />
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

          <ProductsReport rows={s.products} />

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

/** Demonstrativo do período: de onde veio e para onde foi o dinheiro, em blocos separados. */
function Statement({ s }: { s: Summary }) {
  const block = (title: string, total: number, rows: [string, number][], tone: "in" | "out") => (
    <div className="border-t border-zinc-100 pt-3 first:border-0 first:pt-0">
      <div className="flex justify-between font-semibold">
        <span>{title}</span>
        <span className={tone === "in" ? "text-emerald-700" : "text-rose-700"}>
          {tone === "in" ? "" : "− "}
          {formatMoney(total)}
        </span>
      </div>
      {rows.length > 0 && (
        <dl className="mt-1 space-y-1 pl-3 text-sm">
          {rows.map(([label, value]) => (
            <div key={label} className="flex justify-between text-zinc-600">
              <dt>{label}</dt>
              <dd>{formatMoney(value)}</dd>
            </div>
          ))}
        </dl>
      )}
    </div>
  );
  const appointmentCosts = s.commissions + s.serviceMaterialCost + s.productsUsedCost;
  return (
    <Card>
      <h2 className="mb-3 font-semibold">Demonstrativo do período</h2>
      <div className="space-y-3">
        {block("Receitas", s.totalRevenue, [["Serviços", s.servicesRevenue], ["Venda de produtos", s.productSalesRevenue]], "in")}
        {block(
          "Custos dos atendimentos",
          appointmentCosts,
          [
            ["Comissões", s.commissions],
            ["Material dos serviços", s.serviceMaterialCost],
            ["Produtos usados e perdas", s.productsUsedCost],
          ],
          "out",
        )}
        {block("Custo dos produtos vendidos", s.productsSoldCost, [], "out")}
        {block("Despesas fixas", s.fixedExpenses, Object.entries(s.fixedByCategory), "out")}
        {block("Despesas variáveis", s.variableExpenses, Object.entries(s.variableByCategory), "out")}
        <div className="flex justify-between border-t-2 border-zinc-200 pt-3 text-lg font-extrabold">
          <span>Lucro</span>
          <span className={s.profit < 0 ? "text-rose-700" : "text-emerald-700"}>{formatMoney(s.profit)}</span>
        </div>
        {s.rework.count > 0 && (
          <p className="text-xs text-zinc-500">
            Dos custos acima, {formatMoney(s.rework.totalCost)} foram de {s.rework.count} refação(ões) sem cobrança.
          </p>
        )}
      </div>
    </Card>
  );
}

function ReworkCard({ s }: { s: Summary }) {
  const r = s.rework;
  return (
    <Card>
      <h2 className="mb-1 font-semibold">Refações</h2>
      <p className="mb-3 text-sm text-zinc-500">Cliente voltou para refazer e não pagou. Marque “Refação” ao finalizar o atendimento.</p>
      {r.count === 0 ? (
        <Empty>Nenhuma refação no período.</Empty>
      ) : (
        <>
          <dl className="mb-3 space-y-1 text-sm">
            <Row label="Quantidade" value={r.count} />
            <Row label="Material dos serviços" value={formatMoney(r.materialCost)} />
            <Row label="Produtos usados" value={formatMoney(r.productsCost)} />
            <Row label="Custo total" value={<strong className="text-rose-700">{formatMoney(r.totalCost)}</strong>} />
          </dl>
          <ul className="divide-y text-sm">
            {r.items.map((i) => (
              <li key={i.appointmentId} className="flex justify-between py-1.5">
                <span>
                  {formatDate(i.startAt.slice(0, 10))} · {i.customer} · {i.service} <span className="text-zinc-400">({i.professional})</span>
                </span>
                <span>{formatMoney(i.cost)}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </Card>
  );
}

function ProductsReport({ rows }: { rows: ProductReport[] }) {
  const totals = rows.reduce(
    (t, p) => ({ revenue: t.revenue + p.salesRevenue, profit: t.profit + p.salesProfit, used: t.used + p.usedCost, stock: t.stock + p.stockValue }),
    { revenue: 0, profit: 0, used: 0, stock: 0 },
  );
  return (
    <Card className="overflow-x-auto">
      <h2 className="mb-1 font-semibold">Produtos</h2>
      <p className="mb-3 text-sm text-zinc-500">
        Vendas, uso nos atendimentos e estoque no período. Valor em estoque pelo preço pago.
      </p>
      {rows.length === 0 ? (
        <Empty>Nenhum produto cadastrado.</Empty>
      ) : (
        <table className="w-full text-sm">
          <thead className="text-left text-zinc-500">
            <tr>
              <th className="py-1 font-medium">Produto</th>
              <th className="py-1 font-medium">Pago</th>
              <th className="py-1 font-medium">Venda</th>
              <th className="py-1 font-medium">Vendidos</th>
              <th className="py-1 font-medium">Faturado</th>
              <th className="py-1 font-medium">Lucro</th>
              <th className="py-1 font-medium">Usados</th>
              <th className="py-1 font-medium">Perdas</th>
              <th className="py-1 font-medium">Estoque</th>
              <th className="py-1 font-medium">Valor em estoque</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((p) => (
              <tr key={p.id} className="border-t border-zinc-100">
                <td className="py-1.5 font-medium">{p.name}</td>
                <td>{formatMoney(p.costPrice)}</td>
                <td>
                  {p.salePrice > 0 ? formatMoney(p.salePrice) : "—"}
                  {p.salePrice > 0 && p.costPrice > 0 && (
                    <span className="block text-xs text-zinc-500">+{Math.round(((p.salePrice - p.costPrice) / p.costPrice) * 100)}%</span>
                  )}
                </td>
                <td>{qty(p.soldQuantity, p.unit)}</td>
                <td>{formatMoney(p.salesRevenue)}</td>
                <td className={p.salesProfit < 0 ? "text-rose-700" : ""}>{formatMoney(p.salesProfit)}</td>
                <td>
                  {qty(p.usedQuantity, p.unit)}
                  {p.usedCost > 0 && <span className="block text-xs text-zinc-500">{formatMoney(p.usedCost)}</span>}
                </td>
                <td>{p.lostQuantity > 0 ? `${qty(p.lostQuantity, p.unit)} (${formatMoney(p.lostCost)})` : "—"}</td>
                <td className={p.lowStock ? "font-semibold text-rose-700" : ""}>{qty(p.stock, p.unit)}</td>
                <td>{formatMoney(p.stockValue)}</td>
              </tr>
            ))}
            <tr className="border-t-2 border-zinc-200 font-semibold">
              <td className="py-1.5">Total</td>
              <td />
              <td />
              <td />
              <td>{formatMoney(totals.revenue)}</td>
              <td>{formatMoney(totals.profit)}</td>
              <td>{formatMoney(totals.used)}</td>
              <td />
              <td />
              <td>{formatMoney(totals.stock)}</td>
            </tr>
          </tbody>
        </table>
      )}
    </Card>
  );
}

const qty = (n: number, unit: string) => (n === 0 ? "—" : `${Math.round(n * 1000) / 1000} ${unit}`);

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
  const [form, setForm] = useState({ description: "", category: FIXED[0], amount: "", date: isoDate() });
  const [notice, setNotice] = useState<string>();
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

  /** Lança no mês de "até" as despesas fixas do mês anterior (aluguel, água, luz...). */
  async function repeatFixed() {
    const month = to.slice(0, 7);
    setNotice(undefined);
    try {
      const r = await api.post<{ created: number }>("/api/expenses/repeat-fixed", { month });
      setNotice(r.created === 0 ? "Nada novo: as fixas do mês anterior já estão lançadas." : `${r.created} despesa(s) fixa(s) lançada(s).`);
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
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <h2 className="font-semibold">Despesas lançadas</h2>
        <Button variant="secondary" size="sm" className="print:hidden" onClick={repeatFixed}>
          Repetir as fixas do mês anterior
        </Button>
      </div>
      {notice && <p className="mb-2 text-sm text-emerald-700">{notice}</p>}
      <form onSubmit={add} className="mb-4 grid print:hidden gap-2 sm:grid-cols-5 sm:items-end">
        <Field label="Descrição" className="sm:col-span-2" required value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
        <label className="block text-sm">
          <span className="mb-1 block font-medium text-zinc-700">Categoria</span>
          <select className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            <optgroup label="Fixas (todo mês)">
              {FIXED.map((c) => (
                <option key={c}>{c}</option>
              ))}
            </optgroup>
            <optgroup label="Variáveis">
              {VARIABLE.map((c) => (
                <option key={c}>{c}</option>
              ))}
            </optgroup>
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
              {e.fixed && <span className="ml-1 rounded bg-indigo-50 px-1.5 text-xs font-semibold text-indigo-700">fixa</span>}
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
