"use client";

import { useEffect, useState } from "react";
import { Button, ErrorMessage, Field, Modal, Select } from "@/components/ui";
import { api } from "@/lib/api";
import { formatMoney } from "@/lib/format";
import type { Appointment, Product } from "@/lib/types";
import { useApi } from "@/lib/useApi";

type Line = { productId: string; quantity: string; sold: boolean };

export function FinishModal({
  appointment,
  onClose,
  onFinished,
}: {
  appointment: Appointment | null;
  onClose: () => void;
  onFinished: () => void;
}) {
  const [price, setPrice] = useState("");
  const [lines, setLines] = useState<Line[]>([]);
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const { data: products } = useApi<Product[]>(appointment ? "/api/products" : null);

  useEffect(() => {
    if (appointment) {
      setPrice(String(appointment.price));
      setLines([]);
      setError(undefined);
    }
  }, [appointment]);

  const update = (i: number, patch: Partial<Line>) =>
    setLines((ls) => ls.map((l, idx) => (idx === i ? { ...l, ...patch } : l)));

  const valid = lines.filter((l) => l.productId && Number(l.quantity) > 0);
  const sales = valid
    .filter((l) => l.sold)
    .reduce((sum, l) => sum + Number(l.quantity) * (products?.find((p) => p.id === Number(l.productId))?.salePrice ?? 0), 0);

  async function submit() {
    if (!appointment) return;
    setBusy(true);
    setError(undefined);
    const toItems = (sold: boolean) =>
      valid.filter((l) => l.sold === sold).map((l) => ({ productId: Number(l.productId), quantity: Number(l.quantity) }));
    try {
      await api.post(`/api/appointments/${appointment.id}/finish`, {
        price: Number(price),
        usedProducts: toItems(false),
        soldProducts: toItems(true),
      });
      onFinished();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="Finalizar atendimento" open={!!appointment} onClose={onClose}>
      {appointment && (
        <div className="space-y-4">
          <p className="text-sm text-zinc-600">
            {appointment.customer.name} · {appointment.service.name} com {appointment.professional.name}
          </p>
          <Field label="Valor do serviço (R$)" type="number" step="0.01" min="0" value={price} onChange={(e) => setPrice(e.target.value)} />

          <div>
            <p className="mb-2 text-sm font-medium text-zinc-700">Produtos usados ou vendidos</p>
            <div className="space-y-2">
              {lines.map((l, i) => (
                <div key={i} className="flex items-end gap-2">
                  <Select label="Produto" className="flex-1" value={l.productId} onChange={(e) => update(i, { productId: e.target.value })}>
                    <option value="">...</option>
                    {products
                      ?.filter((p) => p.active)
                      .map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.name} ({p.stock} {p.unit})
                        </option>
                      ))}
                  </Select>
                  <Field label="Qtd" className="w-20" type="number" step="0.001" min="0" value={l.quantity} onChange={(e) => update(i, { quantity: e.target.value })} />
                  <Select label="Tipo" className="w-28" value={l.sold ? "sale" : "use"} onChange={(e) => update(i, { sold: e.target.value === "sale" })}>
                    <option value="use">Uso</option>
                    <option value="sale">Venda</option>
                  </Select>
                  <Button variant="ghost" size="sm" onClick={() => setLines((ls) => ls.filter((_, idx) => idx !== i))} aria-label="Remover">
                    ×
                  </Button>
                </div>
              ))}
            </div>
            <Button variant="secondary" size="sm" className="mt-2" onClick={() => setLines((ls) => [...ls, { productId: "", quantity: "1", sold: false }])}>
              + Produto
            </Button>
          </div>

          <div className="rounded-lg bg-zinc-50 p-3 text-sm">
            Total a receber: <strong>{formatMoney(Number(price || 0) + sales)}</strong>
            {sales > 0 && <span className="text-zinc-500"> (inclui {formatMoney(sales)} em produtos)</span>}
          </div>

          <ErrorMessage message={error} />
          <Button className="w-full" onClick={submit} disabled={busy}>
            {busy ? "Salvando..." : "Finalizar"}
          </Button>
        </div>
      )}
    </Modal>
  );
}
