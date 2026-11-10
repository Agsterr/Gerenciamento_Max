"use client";

import Link from "next/link";
import { useState } from "react";
import { Badge, Button, Card, Empty, ErrorMessage, PageHeader, Stat } from "@/components/ui";
import { api } from "@/lib/api";
import { formatCents, formatDateTime, SHOP_STATUS } from "@/lib/format";
import type { ShopOrder } from "@/lib/types";
import { useApi } from "@/lib/useApi";

const STEPS = ["PENDING", "PREPARING", "SHIPPED", "DELIVERED"] as const;

/** "Minhas compras": os pedidos do salão na loja do representante, com a situação de cada um e o que ainda falta pagar. */
export default function PurchasesPage() {
  const { data: orders, error, reload } = useApi<ShopOrder[]>("/api/shop/orders");
  const { data: sales } = useApi<ShopOrder[]>("/api/shop/customer-orders");
  const { data: balance, reload: reloadBalance } = useApi<{ owedCents: number; paidCents: number }>("/api/shop/balance");
  const [msg, setMsg] = useState<string>();

  async function act(fn: () => Promise<unknown>) {
    setMsg(undefined);
    try {
      await fn();
      reload();
      reloadBalance();
    } catch (e) {
      setMsg((e as Error).message);
    }
  }

  return (
    <>
      <PageHeader title="Minhas compras">
        <Link href="/painel/loja" className="bg-brand shadow-glow rounded-xl px-4 py-2 font-bold text-white">
          Ir para a loja
        </Link>
      </PageHeader>
      {balance && (
        <div className="mb-4 grid grid-cols-2 gap-3">
          <Stat label="Falta pagar" value={formatCents(balance.owedCents)} hint="pedidos não cancelados menos o que já foi pago" />
          <Stat label="Já pago" value={formatCents(balance.paidCents)} />
        </div>
      )}
      <ErrorMessage message={error ?? msg} />
      {orders && orders.length === 0 && <Empty>Você ainda não fez pedidos. Abra a loja e escolha o que precisa.</Empty>}
      <div className="space-y-3">
        {orders?.map((o) => {
          const [label, color] = SHOP_STATUS[o.status];
          const step = STEPS.indexOf(o.status as (typeof STEPS)[number]);
          return (
            <Card key={o.id}>
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="font-extrabold text-brand-ink">Pedido #{o.id}</p>
                  <p className="text-sm text-zinc-500">{formatDateTime(o.createdAt)}</p>
                </div>
                <Badge className={color}>{label}</Badge>
              </div>
              {o.status !== "CANCELED" && (
                <ol className="mt-3 flex items-start gap-1 text-xs font-semibold">
                  {STEPS.map((s, i) => (
                    <li key={s} className="flex flex-1 flex-col items-center gap-1 text-center">
                      <span className={`h-1.5 w-full rounded-full ${i <= step ? "bg-brand" : "bg-zinc-200"}`} />
                      <span className={i <= step ? "text-brand-ink" : "text-zinc-400"}>{SHOP_STATUS[s][0]}</span>
                    </li>
                  ))}
                </ol>
              )}
              <ul className="mt-3 divide-y divide-zinc-100 text-sm">
                {o.items.map((i, idx) => (
                  <li key={idx} className="flex justify-between gap-3 py-1.5">
                    <span>
                      {i.quantity} × {i.name}
                    </span>
                    <span className="shrink-0 font-semibold">{formatCents(i.quantity * i.unitCents)}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-3 grid grid-cols-3 gap-2 text-sm">
                <div>
                  <p className="text-zinc-500">Total</p>
                  <p className="font-extrabold">{formatCents(o.totalCents)}</p>
                </div>
                <div>
                  <p className="text-zinc-500">Pago</p>
                  <p className="font-extrabold text-emerald-700">{formatCents(o.paidCents)}</p>
                </div>
                <div>
                  <p className="text-zinc-500">Falta pagar</p>
                  <p className="font-extrabold text-brand-rose">{o.status === "CANCELED" ? "—" : formatCents(o.balanceCents)}</p>
                </div>
              </div>
              {o.status === "SHIPPED" && <p className="mt-2 rounded-xl bg-violet-50 px-3 py-2 text-sm text-violet-900">O representante enviou. Quando receber, confirme.</p>}
              <div className="mt-3 flex flex-wrap gap-2">
                {o.status === "SHIPPED" && (
                  <Button size="sm" onClick={() => act(() => api.post(`/api/shop/orders/${o.id}/received`))}>
                    Confirmar recebimento
                  </Button>
                )}
                {o.status === "PENDING" && (
                  <Button size="sm" variant="danger" onClick={() => confirm(`Cancelar o pedido #${o.id}?`) && act(() => api.post(`/api/shop/orders/${o.id}/cancel`))}>
                    Cancelar pedido
                  </Button>
                )}
              </div>
            </Card>
          );
        })}
      </div>
      {sales && sales.length > 0 && (
        <section className="mt-8">
          <h2 className="text-lg font-extrabold text-brand-ink">Vendas para minhas clientes</h2>
          <p className="mb-3 text-sm text-zinc-600">
            Pedidos que suas clientes fizeram pela sua página. Vão direto ao representante, que entrega e repassa a sua comissão.
          </p>
          <div className="mb-3 grid grid-cols-2 gap-3">
            <Stat
              label="Comissão a receber"
              value={formatCents(sales.filter((o) => o.status === "DELIVERED" && !o.commissionSettled).reduce((t, o) => t + o.commissionCents, 0))}
              hint="de pedidos já entregues"
            />
            <Stat label="Comissão já repassada" value={formatCents(sales.filter((o) => o.commissionSettled).reduce((t, o) => t + o.commissionCents, 0))} />
          </div>
          <div className="space-y-3">
            {sales.map((o) => {
              const [label, color] = SHOP_STATUS[o.status];
              return (
                <Card key={o.id}>
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <p className="font-extrabold text-brand-ink">
                        {o.contactName} · {formatCents(o.totalCents)}
                      </p>
                      <p className="text-sm text-zinc-500">{formatDateTime(o.createdAt)}</p>
                    </div>
                    <Badge className={color}>{label}</Badge>
                  </div>
                  <p className="mt-2 text-sm text-zinc-700">{o.items.map((i) => `${i.quantity} × ${i.name}`).join(", ")}</p>
                  <p className="mt-2 text-sm">
                    Sua comissão: <b className="text-emerald-700">{formatCents(o.commissionCents)}</b>
                    {o.commissionSettled ? " · repassada" : o.status === "DELIVERED" ? " · a receber" : o.status === "CANCELED" ? "" : " · depois da entrega"}
                  </p>
                </Card>
              );
            })}
          </div>
        </section>
      )}
    </>
  );
}
