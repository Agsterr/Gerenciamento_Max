"use client";

import { useEffect, useState } from "react";
import { subscribeLink } from "@/components/PlanBanner";
import { Button, Card, ErrorMessage, Field, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { PlanInfo } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Meu plano: assinar pelo site (Pix, boleto ou cartão) ou cancelar. A versão da loja usa a Google Play. */
export default function SubscriptionPage() {
  const { data: plan, error, reload } = useApi<PlanInfo>("/api/salon/plan");
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string>();
  const [returned, setReturned] = useState<string | null>(null);
  const [cpfCnpj, setCpfCnpj] = useState("");

  useEffect(() => {
    const status = new URLSearchParams(window.location.search).get("assinatura");
    setReturned(status);
    // o Asaas avisa o servidor logo depois do pagamento; recarrega para pegar o plano já ativo
    if (status === "ok") {
      const t = setTimeout(reload, 3000);
      return () => clearTimeout(t);
    }
  }, [reload]);

  async function subscribe() {
    setBusy(true);
    setActionError(undefined);
    try {
      const res = await api.post<{ url: string }>("/api/billing/web/checkout", { cpfCnpj });
      window.location.href = res.url;
    } catch (e) {
      setActionError((e as Error).message);
      setBusy(false);
    }
  }

  async function cancel() {
    if (!confirm("Cancelar a assinatura? Você continua com o plano até o fim do período já pago e não será cobrado de novo.")) return;
    setBusy(true);
    setActionError(undefined);
    try {
      await api.post("/api/billing/web/cancel");
      reload();
    } catch (e) {
      setActionError((e as Error).message);
    } finally {
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

        {!plan.managedByPlay && plan.webBillingAvailable && !(active && plan.managedByWeb) && (
          <Field
            label="CPF ou CNPJ do titular da assinatura"
            className="mt-4 max-w-sm"
            inputMode="numeric"
            placeholder="Só números ou com pontos e traço"
            value={cpfCnpj}
            onChange={(e) => setCpfCnpj(e.target.value)}
          />
        )}

        <div className="mt-4 flex flex-wrap gap-2">
          {plan.managedByPlay && <p className="text-sm text-zinc-600">Seu plano é assinado pela Google Play. Para trocar a forma de pagamento ou cancelar, use a Play Store no celular.</p>}
          {!plan.managedByPlay && plan.webBillingAvailable && !(active && plan.managedByWeb) && (
            <Button disabled={busy} onClick={subscribe}>
              {busy ? "Abrindo..." : active ? "Renovar pelo site" : "Assinar pelo site"}
            </Button>
          )}
          {plan.managedByWeb && (
            <Button variant="secondary" disabled={busy} onClick={cancel}>
              Cancelar assinatura
            </Button>
          )}
          {!plan.webBillingAvailable && !plan.managedByPlay && link && (
            <a href={link} target="_blank" rel="noreferrer" className="bg-brand rounded-xl px-4 py-2 font-bold text-white shadow-glow">
              Falar com o Salão Max para ativar
            </a>
          )}
        </div>
        <p className="mt-4 text-xs text-zinc-500">
          Duas formas de pagar: pelo site, com Pix, boleto ou cartão (cartão renova sozinho; Pix e boleto chegam por e-mail todo mês),
          ou pelo aplicativo na Google Play. Cancelar é a qualquer momento e o plano vale até o fim do período já pago.
        </p>
      </Card>
    </>
  );
}
