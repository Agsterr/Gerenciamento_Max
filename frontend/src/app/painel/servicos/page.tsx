"use client";

import { CrudPage } from "@/components/CrudPage";
import { Badge } from "@/components/ui";
import { formatMoney } from "@/lib/format";
import type { Service } from "@/lib/types";

export default function ServicesPage() {
  return (
    <CrudPage<Service>
      title="Serviços"
      path="/api/services"
      ownerOnly
      servicePhotos
      filter={(s) => s.kitServiceIds.length === 0}
      defaults={{ name: "", category: "", professionalIds: [], description: "", durationMinutes: 30, price: 0, cost: 0, active: true }}
      fields={[
        { key: "name", label: "Nome", required: true, placeholder: "Corte feminino" },
        { key: "category", label: "Categoria", placeholder: "Cabelo, Unhas...", suggestions: ["Cabelo", "Unhas", "Estética", "Barba"] },
        {
          key: "professionalIds",
          label: "Quem faz este serviço",
          type: "professionals",
          hint: "Opcional. Sem nenhum marcado, vale o que cada profissional atende (categorias em Profissionais).",
        },
        { key: "description", label: "Descrição" },
        { key: "durationMinutes", label: "Duração (minutos)", type: "number", required: true },
        { key: "price", label: "Preço (R$)", type: "number", step: "0.01", required: true },
        { key: "cost", label: "Custo de material por atendimento (R$)", type: "number", step: "0.01" },
        { key: "active", label: "Ativo (aparece no agendamento online)", type: "checkbox" },
      ]}
      columns={[
        { label: "Serviço", render: (s) => <span className="font-medium">{s.name}</span> },
        { label: "Categoria", render: (s) => s.category ?? "—", className: "hidden sm:table-cell" },
        { label: "Duração", render: (s) => `${s.durationMinutes} min` },
        { label: "Preço", render: (s) => formatMoney(s.price) },
        { label: "Custo", render: (s) => formatMoney(s.cost), className: "hidden sm:table-cell" },
        {
          label: "Margem",
          className: "hidden sm:table-cell",
          render: (s) => (s.price > 0 ? `${Math.round(((s.price - s.cost) / s.price) * 100)}%` : "—"),
        },
        {
          label: "Status",
          render: (s) =>
            s.active ? <Badge className="bg-emerald-100 text-emerald-800">Ativo</Badge> : <Badge className="bg-zinc-200 text-zinc-600">Inativo</Badge>,
        },
      ]}
    />
  );
}
