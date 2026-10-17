"use client";

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
  if (!plan || plan.status === "ACTIVE") return null;
  const link = subscribeLink(plan);
  const expired = plan.status === "EXPIRED";

  return (
    <div
      className={`mb-4 flex flex-wrap items-center gap-3 rounded-2xl px-4 py-3 text-sm ${
        expired ? "bg-rose-50 text-rose-900 ring-1 ring-rose-200" : "bg-amber-50 text-amber-900 ring-1 ring-amber-200"
      }`}
    >
      <div className="min-w-0 flex-1">
        {expired ? (
          <>
            <p className="font-extrabold">Seu período de teste terminou</p>
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
      {link && (
        <a
          href={link}
          target="_blank"
          rel="noreferrer"
          className="bg-brand shrink-0 rounded-xl px-4 py-2 font-extrabold text-white shadow-glow"
        >
          {expired ? "Ativar meu plano" : "Quero assinar"}
        </a>
      )}
    </div>
  );
}
