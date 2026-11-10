"use client";

import Link from "next/link";
import { whatsappLink } from "@/lib/format";
import type { PlanInfo, TrialTerms } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Link para assinar: WhatsApp com mensagem pronta ou, sem ele, e-mail. */
export function subscribeLink(contact: Pick<TrialTerms, "contactWhatsapp" | "contactEmail">, salonName?: string) {
  const text = `Olá! Quero ativar o plano do Salão Max${salonName ? ` para o ${salonName}` : ""}.`;
  if (contact.contactWhatsapp) return whatsappLink(contact.contactWhatsapp, text);
  if (contact.contactEmail) return `mailto:${contact.contactEmail}?subject=${encodeURIComponent("Ativar plano Salão Max")}&body=${encodeURIComponent(text)}`;
  return null;
}

const limitText = (p: PlanInfo) =>
  `${p.professionals.used}/${p.professionals.max} profissionais · ${p.services.used}/${p.services.max} serviços · ` +
  `${p.customers.used}/${p.customers.max} clientes`;

/** Aviso no topo do painel: dias de teste que faltam, limites usados ou teste vencido. */
export function PlanBanner() {
  const { data: plan } = useApi<PlanInfo>("/api/salon/plan");
  if (!plan) return null;
  const paid = plan.plan === "PAID";
  const ending = plan.status === "ACTIVE" && paid && plan.daysLeft !== null && plan.daysLeft <= 3;
  if (plan.status === "ACTIVE" && !ending) return null;
  const link = subscribeLink(plan);
  const expired = plan.status === "EXPIRED";

  return (
    <div
      className={`mb-4 flex flex-wrap items-center gap-3 rounded-2xl px-4 py-3 text-sm ${
        expired ? "bg-rose-50 text-rose-900 ring-1 ring-rose-200" : "bg-amber-50 text-amber-900 ring-1 ring-amber-200"
      }`}
    >
      <div className="min-w-0 flex-1">
        {ending ? (
          <>
            <p className="font-extrabold">
              {plan.daysLeft === 0 ? "Seu plano vence hoje" : plan.daysLeft === 1 ? "Seu plano vence amanhã" : `Seu plano vence em ${plan.daysLeft} dias`}
            </p>
            <p>Renove para não perder o acesso: depois da data você só consulta os dados.</p>
          </>
        ) : expired ? (
          <>
            <p className="font-extrabold">{paid ? "Seu plano venceu" : "Seu período de teste terminou"}</p>
            <p>Você ainda vê todos os seus dados, mas não pode criar nem alterar nada, e o agendamento online está pausado.</p>
          </>
        ) : (
          <>
            <p className="font-extrabold">
              Teste grátis: {plan.daysLeft === 1 ? "falta 1 dia" : `faltam ${plan.daysLeft} dias`}
            </p>
            <p>{limitText(plan)}</p>
          </>
        )}
      </div>
      {plan.webBillingAvailable ? (
        <Link href="/painel/assinatura" className="bg-brand shrink-0 rounded-xl px-4 py-2 font-extrabold text-white shadow-glow">
          {ending ? "Renovar meu plano" : expired ? "Ativar meu plano" : "Quero assinar"}
        </Link>
      ) : link && (
        <a
          href={link}
          target="_blank"
          rel="noreferrer"
          className="bg-brand shrink-0 rounded-xl px-4 py-2 font-extrabold text-white shadow-glow"
        >
          {ending ? "Renovar meu plano" : expired ? "Ativar meu plano" : "Quero assinar"}
        </a>
      )}
    </div>
  );
}
