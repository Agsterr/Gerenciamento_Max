"use client";

/* eslint-disable @next/next/no-img-element */
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Badge, Button, Card, Empty, ErrorMessage, Field, Modal, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { formatCents, SHOP_TAGS } from "@/lib/format";
import type { SalonInvite, ShopCatalog, ShopOrder, ShopProduct } from "@/lib/types";
import { useApi } from "@/lib/useApi";

type Address = { salonName: string; phone: string | null; address: string | null; neighborhood: string | null; city: string | null };

/** Loja do representante que indicou o salão: o salão escolhe o que mostrar, monta o pedido e acompanha em "Minhas compras". */
export default function ShopPage() {
  const { data: catalog, error, reload } = useApi<ShopCatalog>("/api/shop/catalog");
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState("");
  const [showHidden, setShowHidden] = useState(false);
  const [cart, setCart] = useState<Record<number, number>>({});
  const [ordering, setOrdering] = useState(false);
  const [done, setDone] = useState<ShopOrder>();

  const products = useMemo(() => {
    const t = q.trim().toLowerCase();
    return (catalog?.products ?? []).filter((p) => {
      if (p.hidden && !showHidden) return false;
      if (t && !`${p.name} ${p.category ?? ""} ${p.description ?? ""}`.toLowerCase().includes(t)) return false;
      if (!filter) return true;
      if (filter.startsWith("cat:")) return p.category === filter.slice(4);
      return p.tags.includes(filter);
    });
  }, [catalog, q, filter, showHidden]);

  if (error) return <ErrorMessage message={error} />;
  if (!catalog) return <p className="text-zinc-500">Carregando...</p>;
  if (!catalog.available)
    return (
      <>
        <PageHeader title="Loja do representante" />
        <Invites onChange={reload} />
        <Empty>A loja aparece para salões que se cadastraram pelo link de um representante.</Empty>
      </>
    );

  const lines = catalog.products.filter((p) => cart[p.id] > 0);
  const total = lines.reduce((s, p) => s + p.priceCents * cart[p.id], 0);
  const gain = lines.reduce((s, p) => s + (p.suggestedCents - p.priceCents) * cart[p.id], 0);
  const count = lines.reduce((s, p) => s + cart[p.id], 0);
  const setQty = (id: number, n: number) => setCart((c) => ({ ...c, [id]: Math.max(0, Math.min(999, n)) }));

  const chips: [string, string][] = [
    ["", "Todos"],
    ["NOVO", "Novos"],
    ["PROMOCAO", "Promoções"],
    ["EQUIPAMENTO", "Equipamentos"],
    ...catalog.categories.map((c): [string, string] => ["cat:" + c, c]),
  ];

  return (
    <>
      <PageHeader title="Loja do representante">
        <Link href="/painel/compras" className="rounded-xl bg-white px-4 py-2 font-bold text-brand-ink ring-1 ring-zinc-200">
          Minhas compras
        </Link>
      </PageHeader>
      <p className="mb-4 text-zinc-600">
        Produtos e equipamentos de <b>{catalog.representativeName}</b>. O <b>ganho</b> é o que sobra para você se vender pelo preço sugerido.
      </p>
      <Invites onChange={reload} />
      {catalog.paused && (
        <p className="mb-4 rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-900 ring-1 ring-amber-200">
          A loja de {catalog.representativeName} está pausada no momento. Fale com ele para voltar a fazer pedidos.
        </p>
      )}
      {done && (
        <Card className="mb-4 border border-emerald-200 bg-emerald-50">
          <p className="font-extrabold text-emerald-900">Pedido #{done.id} enviado!</p>
          <p className="text-sm text-emerald-900">
            Acompanhe em <Link href="/painel/compras" className="font-bold underline">Minhas compras</Link>. Quando chegar, confirme o recebimento por lá.
          </p>
        </Card>
      )}

      <div className="mb-3 flex flex-wrap gap-2">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Buscar produto"
          className="min-w-0 flex-1 rounded-xl border border-[#F1E3EB] bg-white px-3 py-2 text-sm outline-none focus:border-brand-rose"
        />
        <label className="flex items-center gap-2 text-sm font-semibold">
          <input type="checkbox" checked={showHidden} onChange={(e) => setShowHidden(e.target.checked)} /> Mostrar ocultos
        </label>
      </div>
      <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
        {chips.map(([k, label]) => (
          <button
            key={k}
            onClick={() => setFilter(k)}
            className={`whitespace-nowrap rounded-full px-3 py-1.5 text-sm font-bold ${filter === k ? "bg-brand text-white" : "bg-white text-brand-muted ring-1 ring-zinc-200"}`}
          >
            {label}
          </button>
        ))}
      </div>

      {products.length === 0 && <Empty>Nenhum produto encontrado.</Empty>}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {products.map((p) => (
          <ProductCard
            key={p.id}
            p={p}
            qty={cart[p.id] ?? 0}
            onQty={(n) => setQty(p.id, n)}
            onVisible={async (v) => {
              await api.put(`/api/shop/products/${p.id}/visible`, { visible: v });
              reload();
            }}
            onShowcase={async (on) => {
              await api.put(`/api/shop/products/${p.id}/showcase`, { on });
              reload();
            }}
          />
        ))}
      </div>

      {count > 0 && (
        <div className="sticky bottom-3 mt-5 flex flex-wrap items-center justify-between gap-3 rounded-2xl bg-night p-4 text-white shadow-lg">
          <div>
            <p className="font-extrabold">
              {count} {count === 1 ? "item" : "itens"} · {formatCents(total)}
            </p>
            <p className="text-sm text-white/80">Se vender tudo pelo sugerido, você ganha {formatCents(gain)}.</p>
          </div>
          <Button onClick={() => setOrdering(true)}>Fazer pedido</Button>
        </div>
      )}

      {ordering && (
        <OrderModal
          lines={lines.map((p) => ({ p, qty: cart[p.id] }))}
          total={total}
          onClose={() => setOrdering(false)}
          onDone={(o) => {
            setOrdering(false);
            setCart({});
            setDone(o);
            window.scrollTo({ top: 0, behavior: "smooth" });
          }}
        />
      )}
    </>
  );
}

function ProductCard({ p, qty, onQty, onVisible, onShowcase }: { p: ShopProduct; qty: number; onQty: (n: number) => void; onVisible: (v: boolean) => void; onShowcase: (on: boolean) => void }) {
  return (
    <Card className={p.hidden ? "opacity-60" : ""}>
      {p.thumbUrl ? (
        <img src={p.imageUrl ?? p.thumbUrl} alt="" loading="lazy" className="mb-3 h-40 w-full rounded-xl object-cover" />
      ) : (
        <div className="mb-3 flex h-40 w-full items-center justify-center rounded-xl bg-zinc-100 text-sm text-zinc-400">sem foto</div>
      )}
      <div className="mb-1 flex flex-wrap gap-1">
        {p.tags.map((t) => (
          <Badge key={t} className={SHOP_TAGS[t]?.[1] ?? "bg-zinc-100"}>
            {SHOP_TAGS[t]?.[0] ?? t}
          </Badge>
        ))}
        {p.hidden && <Badge className="bg-zinc-200 text-zinc-700">Oculto da sua vitrine</Badge>}
        {p.showcase && !p.hidden && <Badge className="bg-sky-100 text-sky-800">Visível para clientes</Badge>}
      </div>
      <p className="font-extrabold text-brand-ink">{p.name}</p>
      {p.category && <p className="text-sm text-zinc-500">{p.category}</p>}
      {p.description && <p className="mt-1 line-clamp-3 text-sm text-zinc-600">{p.description}</p>}
      <div className="mt-3 grid grid-cols-3 gap-2 text-sm">
        <div>
          <p className="text-zinc-500">Você paga</p>
          <p className="font-extrabold">{formatCents(p.priceCents)}</p>
          {p.onPromo && <p className="text-xs text-zinc-400 line-through">{formatCents(p.costCents)}</p>}
        </div>
        <div>
          <p className="text-zinc-500">Vender por</p>
          <p className="font-extrabold">{formatCents(p.suggestedCents)}</p>
        </div>
        <div>
          <p className="text-zinc-500">Seu ganho</p>
          <p className="font-extrabold text-emerald-700">{formatCents(p.gainCents)}</p>
        </div>
      </div>
      {!p.hidden && (
        <label className="mt-3 flex cursor-pointer items-start gap-2 rounded-xl bg-[#FFF1F6] px-3 py-2 text-sm font-semibold text-brand-ink">
          <input type="checkbox" className="mt-0.5" checked={p.showcase} onChange={(e) => onShowcase(e.target.checked)} />
          <span>
            Mostrar para minhas clientes
            <span className="block text-xs font-normal text-zinc-600">
              Aparece na sua página de agendamento por {formatCents(p.suggestedCents)}. O pedido vai direto ao representante e você ganha {formatCents(p.gainCents)} por unidade.
            </span>
          </span>
        </label>
      )}
      <div className="mt-3 flex items-center justify-between gap-2">
        <div className="flex items-center gap-1">
          <button aria-label="Menos" className="h-9 w-9 rounded-xl bg-zinc-100 text-lg font-bold" onClick={() => onQty(qty - 1)}>
            −
          </button>
          <span className="w-8 text-center font-extrabold">{qty}</span>
          <button aria-label="Mais" className="bg-brand h-9 w-9 rounded-xl text-lg font-bold text-white" onClick={() => onQty(qty + 1)}>
            +
          </button>
        </div>
        <button className="text-sm font-semibold text-zinc-500 hover:text-brand-rose" onClick={() => onVisible(p.hidden)}>
          {p.hidden ? "Mostrar na vitrine" : "Ocultar"}
        </button>
      </div>
    </Card>
  );
}

function OrderModal({ lines, total, onClose, onDone }: { lines: { p: ShopProduct; qty: number }[]; total: number; onClose: () => void; onDone: (o: ShopOrder) => void }) {
  const { data: addr } = useApi<Address>("/api/shop/address");
  const [f, setF] = useState({ contactName: "", phone: "", address: "", neighborhood: "", city: "", note: "" });
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (addr) setF((x) => ({ ...x, phone: x.phone || addr.phone || "", address: x.address || addr.address || "", neighborhood: x.neighborhood || addr.neighborhood || "", city: x.city || addr.city || "" }));
  }, [addr]);
  const set = (k: keyof typeof f, v: string) => setF((x) => ({ ...x, [k]: v }));

  return (
    <Modal open title="Fazer pedido" onClose={onClose}>
      <form
        className="space-y-3"
        onSubmit={async (e) => {
          e.preventDefault();
          setBusy(true);
          setError(undefined);
          try {
            const o = await api.post<ShopOrder>("/api/shop/orders", { ...f, items: lines.map((l) => ({ productId: l.p.id, quantity: l.qty })) });
            onDone(o);
          } catch (err) {
            setError((err as Error).message);
          } finally {
            setBusy(false);
          }
        }}
      >
        <ul className="divide-y divide-zinc-100 text-sm">
          {lines.map(({ p, qty }) => (
            <li key={p.id} className="flex justify-between gap-3 py-1.5">
              <span>
                {qty} × {p.name}
              </span>
              <span className="shrink-0 font-semibold">{formatCents(p.priceCents * qty)}</span>
            </li>
          ))}
          <li className="flex justify-between py-2 font-extrabold">
            <span>Total</span>
            <span>{formatCents(total)}</span>
          </li>
        </ul>
        <p className="text-sm font-bold text-brand-ink">Entrega</p>
        <Field label="Quem recebe" value={f.contactName} onChange={(e) => set("contactName", e.target.value)} required />
        <Field label="WhatsApp" inputMode="tel" value={f.phone} onChange={(e) => set("phone", e.target.value)} />
        <Field label="Endereço" value={f.address} onChange={(e) => set("address", e.target.value)} placeholder="Rua, número" />
        <div className="grid grid-cols-2 gap-3">
          <Field label="Bairro" value={f.neighborhood} onChange={(e) => set("neighborhood", e.target.value)} required />
          <Field label="Cidade" value={f.city} onChange={(e) => set("city", e.target.value)} />
        </div>
        <Field label="Observação (opcional)" value={f.note} onChange={(e) => set("note", e.target.value)} />
        <p className="text-xs text-zinc-500">O pagamento é combinado direto com o representante. Esta compra não cobra nada no app.</p>
        <ErrorMessage message={error} />
        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onClose}>
            Voltar
          </Button>
          <Button type="submit" disabled={busy}>
            {busy ? "Enviando..." : "Enviar pedido"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

/** Convites de representantes para este salão. Aceitar um convite quando já há representante não troca a comissão na hora. */
function Invites({ onChange }: { onChange: () => void }) {
  const { data: invites, reload } = useApi<SalonInvite[]>("/api/shop/invites");
  const [error, setError] = useState<string>();
  if (!invites || invites.length === 0) return null;
  async function act(fn: () => Promise<unknown>) {
    setError(undefined);
    try {
      await fn();
      reload();
      onChange();
    } catch (e) {
      setError((e as Error).message);
    }
  }
  return (
    <div className="mb-4 space-y-2">
      {invites.map((i) => (
        <Card key={i.id} className="border border-sky-200 bg-sky-50">
          <p className="font-extrabold text-brand-ink">{i.representativeName} convidou você para a loja dele</p>
          <p className="text-sm text-zinc-700">
            {i.status === "WAITING"
              ? "Você aceitou. Ele só passa a ser o seu representante se o seu plano vencer e você voltar a assinar."
              : i.replacesCurrent
                ? "Você já tem um representante. Se aceitar, o novo só passa a ser o seu se o seu plano vencer e você voltar a assinar."
                : "Aceitando, ele passa a ser o seu representante e você vê os produtos dele aqui."}
          </p>
          {i.status === "PENDING" && (
            <div className="mt-2 flex gap-2">
              <Button size="sm" onClick={() => act(() => api.post(`/api/shop/invites/${i.id}/accept`))}>
                Aceitar
              </Button>
              <Button size="sm" variant="secondary" onClick={() => act(() => api.post(`/api/shop/invites/${i.id}/decline`))}>
                Recusar
              </Button>
            </div>
          )}
          <ErrorMessage message={error} />
        </Card>
      ))}
    </div>
  );
}
