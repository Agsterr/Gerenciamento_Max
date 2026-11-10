"use client";

/* eslint-disable @next/next/no-img-element */
import { useState } from "react";
import { ErrorMessage, Field } from "@/components/ui";
import { api } from "@/lib/api";
import { formatCents } from "@/lib/format";
import type { PublicShopProduct } from "@/lib/types";
import { useApi } from "@/lib/useApi";

type Receipt = { ids: number[]; totalCents: number; vendors: string[] };

/** Produtos que o salão escolheu mostrar (de um fornecedor): a cliente pede aqui e a entrega é feita pelo fornecedor. */
export function ShopShowcase({ base }: { base: string }) {
  const { data: products } = useApi<PublicShopProduct[]>(`${base}/shop-products`);
  const [cart, setCart] = useState<Record<number, number>>({});
  const [open, setOpen] = useState(false);
  const [receipt, setReceipt] = useState<Receipt>();
  if (!products || products.length === 0) return null;

  const lines = products.filter((p) => cart[p.id] > 0);
  const total = lines.reduce((s, p) => s + p.priceCents * cart[p.id], 0);
  const count = lines.reduce((s, p) => s + cart[p.id], 0);
  const setQty = (id: number, n: number) => setCart((c) => ({ ...c, [id]: Math.max(0, Math.min(99, n)) }));

  return (
    <section className="mt-10">
      <h2 className="text-lg font-extrabold">Produtos recomendados pelo salão</h2>
      <p className="mb-3 text-sm text-brand-muted">Peça aqui e receba em casa. A entrega é feita pelo fornecedor parceiro do salão.</p>
      {receipt && (
        <div className="mb-3 rounded-2xl bg-emerald-50 p-4 text-sm text-emerald-900 ring-1 ring-emerald-200">
          <p className="font-extrabold">Pedido enviado!</p>
          <p>
            {receipt.vendors.length === 1
              ? `${receipt.vendors[0]}, o fornecedor,`
              : `Os fornecedores (${receipt.vendors.join(" e ")}) vão falar com você, cada um sobre o seu pedido,`}{" "}
            pelo WhatsApp para combinar a entrega e o pagamento ({formatCents(receipt.totalCents)}).
          </p>
        </div>
      )}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {products.map((p) => (
          <div key={p.id} className="shadow-soft overflow-hidden rounded-2xl bg-white">
            <div className="relative aspect-square bg-[#F6EEF3]">
              {p.thumbUrl ? (
                <a href={p.imageUrl ?? p.thumbUrl} target="_blank" rel="noreferrer">
                  <img src={p.thumbUrl} alt={p.name} loading="lazy" className="h-full w-full object-cover" />
                </a>
              ) : (
                <div className="flex h-full items-center justify-center text-3xl text-brand-muted">📦</div>
              )}
              {p.tags.includes("NOVO") && <span className="absolute left-2 top-2 rounded-full bg-emerald-600 px-2 py-0.5 text-xs font-bold text-white">Novo</span>}
            </div>
            <div className="p-3">
              <p className="truncate text-sm font-bold">{p.name}</p>
              <p className="font-extrabold text-brand-rose">{formatCents(p.priceCents)}</p>
              <p className="truncate text-xs text-brand-muted">Entrega: {p.vendorName}</p>
              <div className="mt-2 flex items-center gap-1">
                <button aria-label="Menos" className="h-8 w-8 rounded-lg bg-zinc-100 font-bold" onClick={() => setQty(p.id, (cart[p.id] ?? 0) - 1)}>
                  −
                </button>
                <span className="w-7 text-center text-sm font-extrabold">{cart[p.id] ?? 0}</span>
                <button aria-label="Mais" className="bg-brand h-8 w-8 rounded-lg font-bold text-white" onClick={() => setQty(p.id, (cart[p.id] ?? 0) + 1)}>
                  +
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
      {count > 0 && !open && (
        <div className="mt-4 flex items-center justify-between gap-3 rounded-2xl bg-night p-4 text-white">
          <p className="font-extrabold">
            {count} {count === 1 ? "item" : "itens"} · {formatCents(total)}
          </p>
          <button className="bg-brand shadow-glow rounded-xl px-4 py-2 font-bold" onClick={() => setOpen(true)}>
            Pedir
          </button>
        </div>
      )}
      {open && (
        <OrderForm
          base={base}
          lines={lines.map((p) => ({ p, qty: cart[p.id] }))}
          total={total}
          onCancel={() => setOpen(false)}
          onDone={(r) => {
            setReceipt(r);
            setOpen(false);
            setCart({});
          }}
        />
      )}
    </section>
  );
}

function OrderForm({ base, lines, total, onCancel, onDone }: { base: string; lines: { p: PublicShopProduct; qty: number }[]; total: number; onCancel: () => void; onDone: (r: Receipt) => void }) {
  const [f, setF] = useState({ name: "", phone: "", address: "", neighborhood: "", city: "", note: "" });
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof f, v: string) => setF((x) => ({ ...x, [k]: v }));
  return (
    <form
      className="shadow-soft mt-4 space-y-3 rounded-2xl bg-white p-4"
      onSubmit={async (e) => {
        e.preventDefault();
        setBusy(true);
        setError(undefined);
        try {
          onDone(await api.post<Receipt>(`${base}/shop-orders`, { ...f, items: lines.map((l) => ({ productId: l.p.id, quantity: l.qty })) }));
        } catch (err) {
          setError((err as Error).message);
        } finally {
          setBusy(false);
        }
      }}
    >
      <p className="font-extrabold">Seu pedido · {formatCents(total)}</p>
      <ul className="text-sm text-zinc-700">
        {lines.map(({ p, qty }) => (
          <li key={p.id}>
            {qty} × {p.name} <span className="text-xs text-brand-muted">({p.vendorName})</span>
          </li>
        ))}
      </ul>
      {new Set(lines.map((l) => l.p.vendorId)).size > 1 && (
        <p className="text-xs font-semibold text-brand-muted">Cada fornecedor recebe um pedido separado e entra em contato com você.</p>
      )}
      <Field label="Seu nome" value={f.name} onChange={(e) => set("name", e.target.value)} required />
      <Field label="WhatsApp" inputMode="tel" value={f.phone} onChange={(e) => set("phone", e.target.value)} required />
      <Field label="Endereço de entrega" value={f.address} onChange={(e) => set("address", e.target.value)} placeholder="Rua, número" />
      <div className="grid grid-cols-2 gap-3">
        <Field label="Bairro" value={f.neighborhood} onChange={(e) => set("neighborhood", e.target.value)} required />
        <Field label="Cidade" value={f.city} onChange={(e) => set("city", e.target.value)} />
      </div>
      <Field label="Observação (opcional)" value={f.note} onChange={(e) => set("note", e.target.value)} />
      <p className="text-xs text-zinc-500">
        O pedido vai para o fornecedor parceiro do salão, que entra em contato pelo WhatsApp. Nada é cobrado agora.
      </p>
      <ErrorMessage message={error} />
      <div className="flex gap-2">
        <button type="button" className="rounded-xl bg-zinc-100 px-4 py-2 font-bold" onClick={onCancel}>
          Voltar
        </button>
        <button disabled={busy} className="bg-brand shadow-glow flex-1 rounded-xl px-4 py-2 font-bold text-white disabled:opacity-50">
          {busy ? "Enviando..." : "Enviar pedido"}
        </button>
      </div>
    </form>
  );
}
