"use client";

/* eslint-disable @next/next/no-img-element */
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Badge, Button, Card, Empty, ErrorMessage, Field, Modal, Select, Stat } from "@/components/ui";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { formatCents, formatDateTime, parseCents, SHOP_STATUS, SHOP_TAGS, whatsappLink } from "@/lib/format";
import type { ShopOrder, ShopProduct, ShopSummary } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Loja do representante: produtos e equipamentos que ele oferece aos salões indicados e os pedidos deles. */
export default function RepShopPage() {
  const { user, ready, signOut } = useAuth();
  const router = useRouter();
  const [tab, setTab] = useState<"orders" | "products">("orders");

  useEffect(() => {
    if (ready && !user) router.replace("/login");
    else if (ready && user && user.role !== "REPRESENTATIVE") router.replace("/painel");
  }, [ready, user, router]);

  if (!user || user.role !== "REPRESENTATIVE") return <p className="p-8 text-center text-zinc-500">Carregando...</p>;

  return (
    <div className="min-h-screen">
      <header className="border-b border-zinc-200 bg-white">
        <div className="mx-auto flex max-w-4xl items-center justify-between gap-3 px-4 py-3">
          <Link href="/representante" className="flex items-center gap-2 text-lg font-extrabold">
            <span className="text-brand">Salão Max</span>
            <span className="text-sm font-bold text-brand-muted">Representante</span>
          </Link>
          <div className="flex items-center gap-3 text-sm">
            <Link href="/representante" className="font-bold text-brand-muted hover:text-brand-rose">Painel</Link>
            <button
              onClick={() => {
                signOut();
                router.push("/login");
              }}
              className="text-zinc-500 hover:text-brand-rose"
            >
              Sair
            </button>
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-4xl space-y-5 p-4 md:p-8">
        <h1 className="text-2xl font-extrabold text-brand-ink">Minha loja</h1>
        <div className="flex gap-2">
          {(
            [
              ["orders", "Pedidos"],
              ["products", "Produtos"],
            ] as const
          ).map(([k, label]) => (
            <button
              key={k}
              onClick={() => setTab(k)}
              className={`rounded-xl px-4 py-2 text-sm font-bold ${tab === k ? "bg-brand text-white shadow-glow" : "bg-white text-brand-muted ring-1 ring-zinc-200"}`}
            >
              {label}
            </button>
          ))}
        </div>
        {tab === "orders" ? <Orders /> : <Products />}
      </main>
    </div>
  );
}

// ---------------------------------------------------------------- pedidos

const NEXT: Record<string, [string, string] | undefined> = {
  PENDING: ["PREPARING", "Aceitar e preparar"],
  PREPARING: ["SHIPPED", "Marcar como enviado"],
};

function Orders() {
  const { data: summary, reload: reloadSummary } = useApi<ShopSummary>("/api/representative/shop/summary");
  const [filter, setFilter] = useState("");
  const { data: orders, error, reload } = useApi<ShopOrder[]>(`/api/representative/shop/orders${filter ? `?status=${filter}` : ""}`);
  const [msg, setMsg] = useState<string>();
  const [paying, setPaying] = useState<ShopOrder>();

  async function act(fn: () => Promise<unknown>) {
    setMsg(undefined);
    try {
      await fn();
      reload();
      reloadSummary();
    } catch (e) {
      setMsg((e as Error).message);
    }
  }

  // entregas do mesmo bairro ficam juntas (o servidor já ordena por bairro)
  const groups: [string, ShopOrder[]][] = [];
  for (const o of orders ?? []) {
    const key = [o.neighborhood || "Sem bairro", o.city].filter(Boolean).join(" · ");
    const last = groups[groups.length - 1];
    if (last && last[0] === key) last[1].push(o);
    else groups.push([key, [o]]);
  }

  return (
    <>
      {summary && (
        <>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Stat label="A receber" value={formatCents(summary.toReceiveCents)} hint="de salões e clientes, menos as baixas" />
            <Stat label="Já recebido" value={formatCents(summary.receivedCents)} />
            <Stat label="Pedidos em andamento" value={String(summary.openOrders)} />
            <Stat label="Novos para aceitar" value={String(summary.pendingOrders)} />
            {summary.commissionOwedCents > 0 && (
              <Stat label="Comissões a repassar" value={formatCents(summary.commissionOwedCents)} hint="de vendas às clientes dos salões, já entregues" />
            )}
          </div>
          {summary.deliveries.length > 0 && (
            <Card>
              <p className="font-extrabold text-brand-ink">Entregas por bairro</p>
              <p className="mb-2 text-sm text-zinc-600">Pedidos ainda não entregues, juntos por bairro para você montar a rota.</p>
              <div className="flex flex-wrap gap-2">
                {summary.deliveries.map((d) => (
                  <span key={d.neighborhood + d.city} className="rounded-xl bg-zinc-100 px-3 py-2 text-sm">
                    <b>{d.neighborhood}</b>
                    {d.city ? ` · ${d.city}` : ""} — {d.orders} {d.orders === 1 ? "pedido" : "pedidos"} · {formatCents(d.totalCents)}
                  </span>
                ))}
              </div>
            </Card>
          )}
        </>
      )}

      <div className="max-w-xs">
        <Select label="Situação" value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="">Todos</option>
          {Object.entries(SHOP_STATUS).map(([k, [label]]) => (
            <option key={k} value={k}>
              {label}
            </option>
          ))}
        </Select>
      </div>
      <ErrorMessage message={error ?? msg} />
      {orders && orders.length === 0 && <Empty>Nenhum pedido por enquanto. Quando um salão indicado por você pedir, ele aparece aqui.</Empty>}
      {groups.map(([place, list]) => (
        <section key={place} className="space-y-3">
          <h2 className="text-sm font-extrabold uppercase tracking-wide text-brand-muted">{place}</h2>
          {list.map((o) => {
            const [label, color] = SHOP_STATUS[o.status];
            const next = NEXT[o.status];
            return (
              <Card key={o.id}>
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="font-extrabold text-brand-ink">
                      #{o.id} · {o.salonName}
                    </p>
                    <p className="text-sm text-zinc-600">
                      {o.contactName}
                      {o.phone ? ` · ${o.phone}` : ""} · {formatDateTime(o.createdAt)}
                    </p>
                    {(o.address || o.neighborhood) && (
                      <p className="text-sm text-zinc-600">
                        {[o.address, o.neighborhood, o.city].filter(Boolean).join(", ")}
                      </p>
                    )}
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <Badge className={color}>{label}</Badge>
                    {o.origin === "CUSTOMER" && <Badge className="bg-sky-100 text-sky-800">Cliente do salão</Badge>}
                  </div>
                </div>
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
                {o.note && <p className="mt-2 rounded-xl bg-amber-50 px-3 py-2 text-sm text-amber-900">Obs.: {o.note}</p>}
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
                    <p className="text-zinc-500">Falta receber</p>
                    <p className="font-extrabold text-brand-rose">{formatCents(o.balanceCents)}</p>
                  </div>
                </div>
                {o.origin === "CUSTOMER" && (
                  <p className="mt-2 rounded-xl bg-sky-50 px-3 py-2 text-sm text-sky-900">
                    Pedido de cliente de <b>{o.salonName}</b>: a cliente paga {formatCents(o.totalCents)}. Comissão do salão:{" "}
                    <b>{formatCents(o.commissionCents)}</b> · fica para você <b>{formatCents(o.netCents)}</b>.
                    {o.commissionSettled && " Comissão já repassada."}
                  </p>
                )}
                {o.payments.length > 0 && (
                  <p className="mt-2 text-xs text-zinc-500">
                    Baixas: {o.payments.map((p) => `${formatCents(p.amountCents)} (${p.method})`).join(" · ")}
                  </p>
                )}
                {o.status === "SHIPPED" && o.origin === "SALON" && <p className="mt-2 text-sm text-violet-700">Aguardando o salão confirmar o recebimento.</p>}
                <div className="mt-3 flex flex-wrap gap-2">
                  {next && (
                    <Button size="sm" onClick={() => act(() => api.put(`/api/representative/shop/orders/${o.id}/status`, { status: next[0] }))}>
                      {next[1]}
                    </Button>
                  )}
                  {o.origin === "CUSTOMER" && o.status === "SHIPPED" && (
                    <Button size="sm" onClick={() => act(() => api.put(`/api/representative/shop/orders/${o.id}/status`, { status: "DELIVERED" }))}>
                      Marcar como entregue
                    </Button>
                  )}
                  {o.origin === "CUSTOMER" && o.status === "DELIVERED" && !o.commissionSettled && (
                    <Button size="sm" onClick={() => act(() => api.post(`/api/representative/shop/orders/${o.id}/commission`))}>
                      Comissão repassada ao salão
                    </Button>
                  )}
                  {o.status === "PENDING" && (
                    <Button size="sm" variant="secondary" onClick={() => act(() => api.put(`/api/representative/shop/orders/${o.id}/status`, { status: "SHIPPED" }))}>
                      Já enviei
                    </Button>
                  )}
                  {o.status !== "CANCELED" && o.balanceCents > 0 && (
                    <Button size="sm" variant="secondary" onClick={() => setPaying(o)}>
                      Dar baixa (pagamento)
                    </Button>
                  )}
                  {o.phone && (
                    <a
                      href={whatsappLink(o.phone, `Olá, ${o.contactName}! Sobre o seu pedido #${o.id} do Salão Max.`)}
                      target="_blank"
                      rel="noreferrer"
                      className="rounded-xl bg-emerald-600 px-3 py-1 text-sm font-bold text-white"
                    >
                      WhatsApp
                    </a>
                  )}
                  {!["DELIVERED", "CANCELED"].includes(o.status) && (
                    <Button
                      size="sm"
                      variant="danger"
                      onClick={() => confirm(`Cancelar o pedido #${o.id}?`) && act(() => api.put(`/api/representative/shop/orders/${o.id}/status`, { status: "CANCELED" }))}
                    >
                      Cancelar
                    </Button>
                  )}
                </div>
              </Card>
            );
          })}
        </section>
      ))}
      {paying && <PaymentModal order={paying} onClose={() => setPaying(undefined)} onSaved={() => { setPaying(undefined); reload(); reloadSummary(); }} />}
    </>
  );
}

function PaymentModal({ order, onClose, onSaved }: { order: ShopOrder; onClose: () => void; onSaved: () => void }) {
  const [amount, setAmount] = useState((order.balanceCents / 100).toFixed(2).replace(".", ","));
  const [method, setMethod] = useState("Pix");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string>();
  return (
    <Modal open title={`Baixa no pedido #${order.id}`} onClose={onClose}>
      <form
        className="space-y-3"
        onSubmit={async (e) => {
          e.preventDefault();
          try {
            await api.post(`/api/representative/shop/orders/${order.id}/payments`, { amountCents: parseCents(amount), method, note });
            onSaved();
          } catch (err) {
            setError((err as Error).message);
          }
        }}
      >
        <p className="text-sm text-zinc-600">Falta receber {formatCents(order.balanceCents)}. Registre o que o salão já pagou.</p>
        <Field label="Valor pago (R$)" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} />
        <Select label="Forma" value={method} onChange={(e) => setMethod(e.target.value)}>
          {["Pix", "Dinheiro", "Cartão", "Desconto na comissão", "Outro"].map((m) => (
            <option key={m}>{m}</option>
          ))}
        </Select>
        <Field label="Observação (opcional)" value={note} onChange={(e) => setNote(e.target.value)} />
        <ErrorMessage message={error} />
        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onClose}>
            Fechar
          </Button>
          <Button type="submit">Registrar baixa</Button>
        </div>
      </form>
    </Modal>
  );
}

// ---------------------------------------------------------------- produtos

const EMPTY = { name: "", description: "", kind: "PRODUCT", category: "", cost: "", suggested: "", promo: "", promoUntil: "", active: true };

function Products() {
  const { data: products, error, reload } = useApi<ShopProduct[]>("/api/representative/shop/products");
  const [editing, setEditing] = useState<ShopProduct | "new">();
  return (
    <>
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm text-zinc-600">
          Cadastre o <b>seu valor</b> (o que o salão paga) e o <b>preço sugerido</b> para vender. A diferença é o ganho do salão.
        </p>
        <Button onClick={() => setEditing("new")}>Novo produto</Button>
      </div>
      <ErrorMessage message={error} />
      {products && products.length === 0 && <Empty>Nenhum produto ainda. Toque em &quot;Novo produto&quot;.</Empty>}
      <div className="grid gap-3 sm:grid-cols-2">
        {products?.map((p) => (
          <Card key={p.id} className={p.active ? "" : "opacity-60"}>
            <div className="flex gap-3">
              {p.thumbUrl ? (
                <img src={p.thumbUrl} alt="" className="h-20 w-20 shrink-0 rounded-xl object-cover" />
              ) : (
                <div className="flex h-20 w-20 shrink-0 items-center justify-center rounded-xl bg-zinc-100 text-xs text-zinc-400">sem foto</div>
              )}
              <div className="min-w-0">
                <p className="font-extrabold text-brand-ink">{p.name}</p>
                <p className="text-sm text-zinc-600">{p.category ?? (p.kind === "EQUIPMENT" ? "Equipamento" : "Produto")}</p>
                <div className="mt-1 flex flex-wrap gap-1">
                  {p.tags.map((t) => (
                    <Badge key={t} className={SHOP_TAGS[t]?.[1] ?? "bg-zinc-100"}>
                      {SHOP_TAGS[t]?.[0] ?? t}
                    </Badge>
                  ))}
                  {!p.active && <Badge className="bg-zinc-200 text-zinc-700">Oculto</Badge>}
                </div>
              </div>
            </div>
            <div className="mt-3 grid grid-cols-3 gap-2 text-sm">
              <div>
                <p className="text-zinc-500">Seu valor</p>
                <p className="font-extrabold">{formatCents(p.priceCents)}</p>
                {p.onPromo && <p className="text-xs text-zinc-400 line-through">{formatCents(p.costCents)}</p>}
              </div>
              <div>
                <p className="text-zinc-500">Sugerido</p>
                <p className="font-extrabold">{formatCents(p.suggestedCents)}</p>
              </div>
              <div>
                <p className="text-zinc-500">Ganho do salão</p>
                <p className="font-extrabold text-emerald-700">{formatCents(p.gainCents)}</p>
              </div>
            </div>
            <div className="mt-3 flex gap-2">
              <Button size="sm" variant="secondary" onClick={() => setEditing(p)}>
                Editar
              </Button>
              <Button
                size="sm"
                variant="danger"
                onClick={async () => {
                  if (!confirm(`Excluir "${p.name}"? Os pedidos antigos continuam guardados.`)) return;
                  await api.del(`/api/representative/shop/products/${p.id}`);
                  reload();
                }}
              >
                Excluir
              </Button>
            </div>
          </Card>
        ))}
      </div>
      {editing && <ProductModal product={editing === "new" ? undefined : editing} onClose={() => setEditing(undefined)} onSaved={() => { setEditing(undefined); reload(); }} />}
    </>
  );
}

function ProductModal({ product, onClose, onSaved }: { product?: ShopProduct; onClose: () => void; onSaved: () => void }) {
  const money = (c: number | null) => (c == null ? "" : (c / 100).toFixed(2).replace(".", ","));
  const [f, setF] = useState(
    product
      ? { name: product.name, description: product.description ?? "", kind: product.kind, category: product.category ?? "", cost: money(product.costCents),
          suggested: money(product.suggestedCents), promo: money(product.promoCents), promoUntil: product.promoUntil ?? "", active: product.active }
      : EMPTY,
  );
  const [file, setFile] = useState<File>();
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof EMPTY, v: string | boolean) => setF((x) => ({ ...x, [k]: v }));

  return (
    <Modal open title={product ? "Editar produto" : "Novo produto"} onClose={onClose}>
      <form
        className="space-y-3"
        onSubmit={async (e) => {
          e.preventDefault();
          setBusy(true);
          setError(undefined);
          try {
            const body = {
              name: f.name, description: f.description, kind: f.kind, category: f.category, costCents: parseCents(f.cost),
              suggestedCents: parseCents(f.suggested), promoCents: f.promo ? parseCents(f.promo) : null, promoUntil: f.promo && f.promoUntil ? f.promoUntil : null,
              active: f.active,
            };
            const saved = product
              ? await api.put<ShopProduct>(`/api/representative/shop/products/${product.id}`, body)
              : await api.post<ShopProduct>("/api/representative/shop/products", body);
            if (file) {
              const form = new FormData();
              form.append("file", file);
              await api.upload(`/api/representative/shop/products/${saved.id}/photo`, form);
            }
            onSaved();
          } catch (err) {
            setError((err as Error).message);
          } finally {
            setBusy(false);
          }
        }}
      >
        <Field label="Nome" value={f.name} onChange={(e) => set("name", e.target.value)} required />
        <div className="grid grid-cols-2 gap-3">
          <Select label="Tipo" value={f.kind} onChange={(e) => set("kind", e.target.value)}>
            <option value="PRODUCT">Produto</option>
            <option value="EQUIPMENT">Equipamento (chapinha, secador...)</option>
          </Select>
          <Field label="Categoria" value={f.category} onChange={(e) => set("category", e.target.value)} placeholder="Ex.: Cabelo, Unhas" />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Seu valor (R$)" inputMode="decimal" value={f.cost} onChange={(e) => set("cost", e.target.value)} required />
          <Field label="Preço sugerido de venda (R$)" inputMode="decimal" value={f.suggested} onChange={(e) => set("suggested", e.target.value)} required />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Valor em promoção (R$)" inputMode="decimal" value={f.promo} onChange={(e) => set("promo", e.target.value)} placeholder="opcional" />
          <Field label="Promoção vai até" type="date" value={f.promoUntil} onChange={(e) => set("promoUntil", e.target.value)} />
        </div>
        <label className="block text-sm">
          <span className="mb-1 block font-semibold text-brand-ink">Descrição</span>
          <textarea
            className="w-full rounded-xl border border-[#F1E3EB] bg-white px-3 py-2.5 outline-none focus:border-brand-rose"
            rows={3}
            value={f.description}
            onChange={(e) => set("description", e.target.value)}
          />
        </label>
        <label className="block text-sm">
          <span className="mb-1 block font-semibold text-brand-ink">Foto</span>
          <input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0])} />
        </label>
        <label className="flex items-center gap-2 text-sm font-semibold">
          <input type="checkbox" checked={f.active} onChange={(e) => set("active", e.target.checked)} /> Aparece na loja dos salões
        </label>
        <ErrorMessage message={error} />
        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" disabled={busy}>
            {busy ? "Salvando..." : "Salvar"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
