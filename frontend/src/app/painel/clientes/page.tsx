"use client";

import { useState } from "react";
import { CrudPage } from "@/components/CrudPage";
import { Badge, Button, Empty, Modal } from "@/components/ui";
import { STATUS_COLOR, STATUS_LABEL, formatDateTime, formatMoney, formatPhone } from "@/lib/format";
import type { Appointment, Customer } from "@/lib/types";
import { useApi } from "@/lib/useApi";

export default function CustomersPage() {
  const [query, setQuery] = useState("");
  const [history, setHistory] = useState<Customer | null>(null);

  return (
    <>
      <CrudPage<Customer>
        title="Clientes"
        path="/api/customers"
        listPath={`/api/customers?q=${encodeURIComponent(query)}`}
        toolbar={
          <input
            placeholder="Buscar nome ou telefone"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="rounded-lg border border-zinc-300 px-3 py-2 text-sm"
          />
        }
        defaults={{ name: "", phone: "", email: "", notes: "" }}
        fields={[
          { key: "name", label: "Nome", required: true },
          { key: "phone", label: "Telefone (WhatsApp)", type: "tel", required: true },
          { key: "email", label: "E-mail", type: "email" },
          { key: "notes", label: "Observações (alergias, preferências...)" },
        ]}
        columns={[
          { label: "Nome", render: (c) => <span className="font-medium">{c.name}</span> },
          {
            label: "Telefone",
            render: (c) => (
              <a href={`https://wa.me/55${c.phone}`} target="_blank" rel="noreferrer" className="text-emerald-700 hover:underline">
                {formatPhone(c.phone)}
              </a>
            ),
          },
          { label: "Observações", render: (c) => c.notes ?? "", className: "hidden md:table-cell text-zinc-500" },
        ]}
        rowActions={(c) => (
          <Button variant="ghost" size="sm" onClick={() => setHistory(c)}>
            Histórico
          </Button>
        )}
      />
      <HistoryModal customer={history} onClose={() => setHistory(null)} />
    </>
  );
}

function HistoryModal({ customer, onClose }: { customer: Customer | null; onClose: () => void }) {
  const { data } = useApi<Appointment[]>(customer ? `/api/customers/${customer.id}/appointments` : null);
  const done = data?.filter((a) => a.status === "DONE") ?? [];

  return (
    <Modal title={`Histórico · ${customer?.name ?? ""}`} open={!!customer} onClose={onClose}>
      {data && data.length === 0 && <Empty>Sem atendimentos ainda.</Empty>}
      {done.length > 0 && (
        <p className="mb-3 text-sm text-zinc-600">
          {done.length} atendimento(s) · total gasto {formatMoney(done.reduce((s, a) => s + a.price, 0))}
        </p>
      )}
      <ul className="divide-y">
        {data?.map((a) => (
          <li key={a.id} className="flex items-start justify-between gap-3 py-2 text-sm">
            <div>
              <p className="font-medium">{a.service.name}</p>
              <p className="text-zinc-500">
                {formatDateTime(a.startAt)} · {a.professional.name}
              </p>
              {a.serviceNotes && (
                <p className="mt-1 whitespace-pre-line rounded-lg bg-amber-50 px-2 py-1 text-xs text-amber-900">{a.serviceNotes}</p>
              )}
            </div>
            <div className="text-right">
              <Badge className={STATUS_COLOR[a.status]}>{STATUS_LABEL[a.status]}</Badge>
              <p>{formatMoney(a.price)}</p>
            </div>
          </li>
        ))}
      </ul>
    </Modal>
  );
}
