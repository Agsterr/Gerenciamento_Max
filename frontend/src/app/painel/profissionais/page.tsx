"use client";

import { CrudPage } from "@/components/CrudPage";
import { Badge } from "@/components/ui";
import { formatPhone } from "@/lib/format";
import type { Professional } from "@/lib/types";

export default function ProfessionalsPage() {
  return (
    <CrudPage<Professional>
      title="Profissionais"
      path="/api/professionals"
      ownerOnly
      defaults={{ name: "", phone: "", categories: [], commissionPercent: 0, active: true }}
      fields={[
        { key: "name", label: "Nome", required: true },
        {
          key: "categories",
          label: "Atende (categorias)",
          type: "categories",
          suggestions: ["Cabelo", "Unhas", "Estética", "Barba"],
          hint: "O que você marcar define os serviços desta pessoa. Sem nenhuma marcada, ela faz todos.",
        },
        { key: "phone", label: "Telefone", type: "tel" },
        { key: "commissionPercent", label: "Comissão (%)", type: "number", step: "0.01", required: true },
        { key: "active", label: "Ativo (recebe agendamentos)", type: "checkbox" },
      ]}
      columns={[
        { label: "Nome", render: (p) => <span className="font-medium">{p.name}</span> },
        { label: "Telefone", render: (p) => (p.phone ? formatPhone(p.phone) : "—") },
        { label: "Atende", render: (p) => (p.categories.length ? p.categories.join(", ") : "Todos os serviços"), className: "hidden sm:table-cell" },
        { label: "Comissão", render: (p) => `${p.commissionPercent}%` },
        {
          label: "Status",
          render: (p) =>
            p.active ? <Badge className="bg-emerald-100 text-emerald-800">Ativo</Badge> : <Badge className="bg-zinc-200 text-zinc-600">Inativo</Badge>,
        },
      ]}
    />
  );
}
