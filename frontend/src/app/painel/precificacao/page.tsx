"use client";

import { useEffect, useState } from "react";
import { Button, Card, Empty, ErrorMessage, Field, PageHeader, Stat } from "@/components/ui";
import { api } from "@/lib/api";
import { formatMoney } from "@/lib/format";
import type { Pricing, PricingHealth, PricingSettings, Service, ServicePricing } from "@/lib/types";
import { useApi } from "@/lib/useApi";

const HEALTH: Record<PricingHealth, { label: string; className: string }> = {
  LOSS: { label: "Prejuízo", className: "bg-rose-100 text-rose-800" },
  LOW: { label: "Margem baixa", className: "bg-amber-100 text-amber-800" },
  HEALTHY: { label: "Saudável", className: "bg-emerald-100 text-emerald-800" },
  NO_PRICE: { label: "Sem preço", className: "bg-zinc-200 text-zinc-700" },
};

/** Lucro e margem para um preço qualquer (mesma conta do backend). */
function simulate(p: ServicePricing, price: number) {
  const profit = price - p.directCost - (price * p.variablePercent) / 100;
  return { profit, margin: price > 0 ? (profit / price) * 100 : 0 };
}

export default function PricingPage() {
  const { data, error, reload } = useApi<Pricing>("/api/pricing");
  const { data: services, reload: reloadServices } = useApi<Service[]>("/api/services");
  const [form, setForm] = useState<Record<keyof PricingSettings, string> | null>(null);
  const [saveError, setSaveError] = useState<string>();
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (data && !form) {
      const s = data.basis.settings;
      setForm({
        cardFeePercent: String(s.cardFeePercent),
        targetMarginPercent: String(s.targetMarginPercent),
        occupancyPercent: String(s.occupancyPercent),
        fixedMonthlyCost: s.fixedMonthlyCost == null ? "" : String(s.fixedMonthlyCost),
      });
    }
  }, [data, form]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form) return;
    setSaving(true);
    setSaveError(undefined);
    try {
      await api.put("/api/pricing/settings", {
        cardFeePercent: Number(form.cardFeePercent),
        targetMarginPercent: Number(form.targetMarginPercent),
        occupancyPercent: Number(form.occupancyPercent),
        fixedMonthlyCost: form.fixedMonthlyCost === "" ? null : Number(form.fixedMonthlyCost),
      });
      await reload();
    } catch (err) {
      setSaveError((err as Error).message);
    } finally {
      setSaving(false);
    }
  }

  async function applyPrice(p: ServicePricing, price: number) {
    const s = services?.find((x) => x.id === p.serviceId);
    if (!s || !confirm(`Mudar o preço de ${s.name} de ${formatMoney(s.price)} para ${formatMoney(price)}?`)) return;
    await api.put(`/api/services/${s.id}`, { ...s, price });
    await Promise.all([reload(), reloadServices()]);
  }

  const b = data?.basis;
  const losing = data?.services.filter((s) => s.health === "LOSS").length ?? 0;

  return (
    <>
      <PageHeader title="Precificação" />
      <p className="-mt-2 mb-6 max-w-3xl text-brand-muted">
        Descubra quanto cada serviço precisa custar para pagar material, comissão, taxas e a sua parte das despesas fixas
        do salão — e ainda sobrar o lucro que você quer.
      </p>
      <ErrorMessage message={error} />

      {b && form && (
        <div className="grid gap-4 lg:grid-cols-3">
          <Card className="lg:col-span-1">
            <h2 className="mb-3 font-extrabold">Seus parâmetros</h2>
            <form onSubmit={save} className="space-y-3">
              <Field label="Lucro desejado (%)" type="number" step="0.5" min="0" max="80" required value={form.targetMarginPercent}
                onChange={(e) => setForm({ ...form, targetMarginPercent: e.target.value })} />
              <Field label="Taxa de cartão + impostos (%)" type="number" step="0.1" min="0" max="50" required value={form.cardFeePercent}
                onChange={(e) => setForm({ ...form, cardFeePercent: e.target.value })} />
              <Field label="Ocupação média da agenda (%)" type="number" step="1" min="5" max="100" required value={form.occupancyPercent}
                onChange={(e) => setForm({ ...form, occupancyPercent: e.target.value })} />
              <Field
                label="Custo fixo mensal (R$)"
                type="number"
                step="0.01"
                min="0"
                placeholder={`Média das despesas: ${formatMoney(b.fixedCostFromExpenses ? b.monthlyFixedCost : 0)}`}
                value={form.fixedMonthlyCost}
                onChange={(e) => setForm({ ...form, fixedMonthlyCost: e.target.value })}
              />
              <p className="text-xs text-brand-muted">
                Deixe em branco para usar a média das despesas lançadas no Financeiro nos últimos 3 meses (aluguel, luz,
                salários fixos, marketing…).
              </p>
              <ErrorMessage message={saveError} />
              <Button className="w-full" disabled={saving}>{saving ? "Recalculando..." : "Recalcular"}</Button>
            </form>
          </Card>

          <div className="space-y-4 lg:col-span-2">
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              <Stat label="Custo fixo do mês" value={formatMoney(b.monthlyFixedCost)} hint={b.fixedCostFromExpenses ? "média das despesas" : "valor informado"} />
              <Stat label="Horas vendidas/mês" value={`${b.sellableHoursPerMonth} h`} hint={`${b.activeProfessionals} profissional(is) · ${b.settings.occupancyPercent}% ocupação`} />
              <Stat label="Custo fixo por hora" value={formatMoney(b.fixedCostPerHour)} hint="cada hora de cadeira" />
              <Stat label="Comissão média" value={`${b.averageCommissionPercent}%`} hint="dos profissionais ativos" />
            </div>
            {losing > 0 && (
              <p className="rounded-2xl bg-rose-50 px-4 py-3 text-sm font-semibold text-rose-800">
                {losing} serviço(s) dão prejuízo no preço atual. Veja o preço mínimo e o sugerido abaixo.
              </p>
            )}
            <details className="rounded-2xl bg-white p-4 text-sm text-brand-muted shadow-soft">
              <summary className="cursor-pointer font-bold text-brand-ink">Como calculamos</summary>
              <ul className="mt-2 list-disc space-y-1 pl-5">
                <li><b>Custo direto</b> = material + custo fixo por hora × duração (usamos o tempo real quando ele é maior que o previsto).</li>
                <li><b>Preço mínimo</b> = custo direto ÷ (1 − comissão − taxas). Abaixo dele o serviço dá prejuízo.</li>
                <li><b>Preço sugerido</b> = custo direto ÷ (1 − comissão − taxas − lucro desejado), arredondado para cima de R$ 5 em R$ 5.</li>
                <li>Compare também com os preços da sua região: o sugerido é o piso saudável, não o teto.</li>
              </ul>
            </details>
          </div>
        </div>
      )}

      <div className="mt-6 space-y-4">
        {data && data.services.length === 0 && (
          <Card><Empty>Cadastre serviços para ver a precificação.</Empty></Card>
        )}
        {data?.services.map((p) => <ServiceRow key={p.serviceId} p={p} target={data.basis.settings.targetMarginPercent} onApply={applyPrice} />)}
      </div>
    </>
  );
}

function ServiceRow({ p, target, onApply }: { p: ServicePricing; target: number; onApply: (p: ServicePricing, price: number) => void }) {
  const [sim, setSim] = useState("");
  const simPrice = Number(sim.replace(",", "."));
  const simulated = sim ? simulate(p, simPrice) : null;
  const price = p.currentPrice || 1;
  const variable = (price * p.variablePercent) / 100;
  // composição do preço atual (barra empilhada)
  const parts = [
    { label: "Material", value: p.materialCost, color: "#38BDF8" },
    { label: "Custo fixo", value: p.fixedCostShare, color: "#8E2DE2" },
    { label: "Comissão + taxas", value: variable, color: "#FFB547" },
    { label: p.currentProfit >= 0 ? "Lucro" : "Prejuízo", value: Math.abs(p.currentProfit), color: p.currentProfit >= 0 ? "#10B981" : "#E11D48" },
  ];
  const total = parts.reduce((s, x) => s + x.value, 0) || 1;
  const h = HEALTH[p.health];

  return (
    <Card className="p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h3 className="text-lg font-extrabold">{p.name}</h3>
          <p className="text-sm text-brand-muted">
            {p.plannedMinutes} min previstos
            {p.realAverageMinutes != null && ` · ${p.realAverageMinutes} min reais em média`}
            {" · "}lucro de {formatMoney(p.profitPerHour)} por hora
          </p>
        </div>
        <span className={`rounded-full px-3 py-1 text-xs font-bold ${h.className}`}>{h.label}</span>
      </div>

      <div className="mt-4 grid gap-3 sm:grid-cols-4">
        <Metric label="Preço atual" value={formatMoney(p.currentPrice)} hint={p.currentMarginPercent != null ? `${p.currentMarginPercent}% de lucro` : undefined} />
        <Metric label="Custo direto" value={formatMoney(p.directCost)} hint={`material ${formatMoney(p.materialCost)} + fixo ${formatMoney(p.fixedCostShare)}`} />
        <Metric label="Preço mínimo" value={p.breakEvenPrice != null ? formatMoney(p.breakEvenPrice) : "—"} hint="lucro zero" />
        <Metric label="Preço sugerido" value={p.suggestedPrice != null ? formatMoney(p.suggestedPrice) : "—"} hint={`para ${target}% de lucro`} highlight />
      </div>

      <div className="mt-4">
        <div className="flex h-3 overflow-hidden rounded-full bg-[#F6EEF3]">
          {parts.map((x) => (
            <div key={x.label} style={{ width: `${(x.value / total) * 100}%`, background: x.color }} title={`${x.label}: ${formatMoney(x.value)}`} />
          ))}
        </div>
        <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-brand-muted">
          {parts.map((x) => (
            <span key={x.label} className="inline-flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-full" style={{ background: x.color }} /> {x.label} {formatMoney(x.value)}
            </span>
          ))}
        </div>
      </div>

      <div className="mt-4 flex flex-wrap items-end gap-3 border-t border-[#F1E3EB] pt-4">
        <Field label="Simular preço (R$)" className="w-44" type="number" step="0.01" min="0" value={sim} onChange={(e) => setSim(e.target.value)} />
        {simulated && (
          <p className={`pb-2.5 text-sm font-bold ${simulated.profit < 0 ? "text-rose-700" : simulated.margin < target ? "text-amber-700" : "text-emerald-700"}`}>
            {simulated.profit < 0 ? "Prejuízo" : "Lucro"} de {formatMoney(Math.abs(simulated.profit))} por atendimento ({simulated.margin.toFixed(1)}%)
          </p>
        )}
        <div className="ml-auto flex gap-2">
          {simulated && simPrice > 0 && (
            <Button variant="secondary" onClick={() => onApply(p, simPrice)}>Usar {formatMoney(simPrice)}</Button>
          )}
          {p.suggestedPrice != null && p.currentPrice < p.suggestedPrice ? (
            <Button onClick={() => onApply(p, p.suggestedPrice!)}>Subir para {formatMoney(p.suggestedPrice)}</Button>
          ) : (
            p.suggestedPrice != null && <p className="pb-2.5 text-sm font-semibold text-emerald-700">Seu preço já cobre o sugerido</p>
          )}
        </div>
      </div>
    </Card>
  );
}

function Metric({ label, value, hint, highlight }: { label: string; value: string; hint?: string; highlight?: boolean }) {
  return (
    <div className={`rounded-2xl p-3 ${highlight ? "bg-brand text-white shadow-glow" : "bg-[#FFF7FA]"}`}>
      <p className={`text-xs font-semibold ${highlight ? "text-white/85" : "text-brand-muted"}`}>{label}</p>
      <p className="text-xl font-extrabold">{value}</p>
      {hint && <p className={`text-xs ${highlight ? "text-white/80" : "text-brand-muted"}`}>{hint}</p>}
    </div>
  );
}
