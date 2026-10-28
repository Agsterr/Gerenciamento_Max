"use client";

import { useEffect, useState } from "react";
import { subscribeLink } from "@/components/PlanBanner";
import { Button, Card, ErrorMessage, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { PlanInfo } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Meu plano: assinar pelo site (cartão), trocar o cartão ou cancelar. A versão da loja usa a Google Play. */
export default function SubscriptionPage() {
  const { data: plan, error, reload } = useApi<PlanInfo>("/api/salon/plan");
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string>();
  const [returned, setReturned] = useState<string | null>(null);

  useEffect(() => {
    const status = new URLSearchParams(window.location.search).get("assinatura");
    setReturned(status);
    // o Stripe avisa o servidor logo depois do pagamento; recarrega para pegar o plano já ativo
    if (status === "ok") {
      const t = setTimeout(reload, 3000);
      return () => clearTimeout(t);
    }
  }, [reload]);

  async function open(path: string) {
    setBusy(true);
    setActionError(undefined);
    try {
      const res = await api.post<{ url: string }>(path);
      window.location.href = res.url;
    } catch (e) {
      setActionError((e as Error).message);
      setBusy(false);
    }
  }

  if (error) return <ErrorMessage message={error} />;
  if (!plan) return <p className="text-zinc-500">Carregando...</p>;

  const active = plan.status === "ACTIVE";
  const link = subscribeLink(plan);

  return (
    <>
      <PageHeader title="Meu plano" />
      {returned === "ok" && (
        <p className="mb-4 rounded-xl bg-emerald-50 px-4 py-3 text-sm text-emerald-900 ring-1 ring-emerald-200">
          Pagamento recebido! Em instantes o seu plano aparece como ativo.
        </p>
      )}
      {returned === "cancelada" && (
        <p className="mb-4 rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-900 ring-1 ring-amber-200">
          O pagamento não foi concluído. Você pode tentar de novo quando quiser.
        </p>
      )}
      <Card className="max-w-xl">
        <p className="text-sm text-zinc-500">Situação</p>
        <p className="text-xl font-extrabold text-brand-ink">
          {plan.status === "ACTIVE" ? "Plano ativo" : plan.status === "TRIAL" ? "Teste grátis" : "Plano vencido"}
        </p>
        {plan.status === "TRIAL" && (
          <p className="mt-1 text-sm text-zinc-600">{plan.daysLeft === 1 ? "Falta 1 dia" : `Faltam ${plan.daysLeft} dias`} de teste.</p>
        )}
        {active && plan.paidUntil && <p className="mt-1 text-sm text-zinc-600">Pago até {formatDate(plan.paidUntil)}.</p>}
        {plan.status === "EXPIRED" && (
          <p className="mt-1 text-sm text-zinc-600">Você ainda vê seus dados, mas para cadastrar e receber agendamentos é preciso ativar o plano.</p>
        )}

        <ErrorMessage message={actionError} />

        <div className="mt-4 flex flex-wrap gap-2">
          {plan.managedByPlay && <p className="text-sm text-zinc-600">Seu plano é assinado pela Google Play. Para trocar a forma de pagamento ou cancelar, use a Play Store no celular.</p>}
          {!plan.managedByPlay && plan.webBillingAvailable && !(active && plan.managedByStripe) && (
            <Button disabled={busy} onClick={() => open("/api/billing/web/checkout")}>
              {busy ? "Abrindo..." : active ? "Renovar pelo site" : "Assinar pelo site"}
            </Button>
          )}
          {plan.managedByStripe && (
            <Button variant="secondary" disabled={busy} onClick={() => open("/api/billing/web/portal")}>
              Gerenciar assinatura (cartão, faturas, cancelar)
            </Button>
          )}
          {!plan.webBillingAvailable && !plan.managedByPlay && link && (
            <a href={link} target="_blank" rel="noreferrer" className="bg-brand rounded-xl px-4 py-2 font-bold text-white shadow-glow">
              Falar com o Salão Max para ativar
            </a>
          )}
        </div>
        <p className="mt-4 text-xs text-zinc-500">
          Duas formas de pagar: pelo site, com cartão, ou pelo aplicativo na Google Play. Cancelar é a qualquer momento e o plano
          vale até o fim do período já pago.
        </p>
      </Card>
    </>
  );
}
