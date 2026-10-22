"use client";

import { useState } from "react";
import { CrudPage } from "@/components/CrudPage";
import { Badge, Button, ErrorMessage, Field, Modal, Select } from "@/components/ui";
import { api } from "@/lib/api";
import { formatDateTime, formatMoney } from "@/lib/format";
import type { Movement, MovementType, Product } from "@/lib/types";
import { useApi } from "@/lib/useApi";

const MOVEMENT_LABEL: Record<MovementType, string> = {
  IN: "Entrada (compra)",
  SALE: "Venda",
  USE: "Uso em atendimento",
  LOSS: "Perda / ajuste",
};

/** % de ganho em cima do custo: (venda - custo) / custo. */
function markupOf(cost: number, price: number) {
  return cost > 0 ? `${Math.round(((price - cost) / cost) * 1000) / 10}%` : "—";
}

const round2 = (n: number) => Math.round(n * 100) / 100;

/**
 * Custo ou margem mudou: calcula o preço de venda. Preço mudou: mostra quanto % ele dá em cima do custo.
 */
function productPricing(key: string, v: Record<string, unknown>) {
  const cost = Number(v.costPrice) || 0;
  const markup = v.markupPercent === "" || v.markupPercent == null ? null : Number(v.markupPercent);
  if ((key === "costPrice" || key === "markupPercent") && markup != null && cost > 0) {
    return { ...v, salePrice: round2(cost * (1 + markup / 100)) };
  }
  if (key === "salePrice" && cost > 0 && Number(v.salePrice) > 0) {
    return { ...v, markupPercent: Math.round(((Number(v.salePrice) - cost) / cost) * 1000) / 10 };
  }
  return v;
}

function ProfitPreview({ cost, price }: { cost: number; price: number }) {
  if (price <= 0) return <p className="text-xs text-zinc-500">Preço 0: produto só para uso nos atendimentos.</p>;
  const profit = price - cost;
  return (
    <div className={`rounded-lg p-3 text-sm ${profit < 0 ? "bg-rose-50 text-rose-800" : "bg-emerald-50 text-emerald-800"}`}>
      Lucro por unidade: <strong>{formatMoney(profit)}</strong> · {markupOf(cost, price)} em cima do custo
      {price > 0 && ` · margem de ${Math.round((profit / price) * 100)}% do preço`}
      {profit < 0 && " — vendendo com prejuízo!"}
    </div>
  );
}

export default function ProductsPage() {
  const [moving, setMoving] = useState<{ product: Product; reload: () => void } | null>(null);

  return (
    <>
      <CrudPage<Product>
        title="Produtos e estoque"
        path="/api/products"
        productPhotos
        defaults={{ name: "", costPrice: 0, markupPercent: "", salePrice: 0, minStock: 0, unit: "un", active: true }}
        fields={[
          { key: "name", label: "Nome", required: true },
          { key: "unit", label: "Unidade (un, ml, g...)", required: true },
          { key: "costPrice", label: "Preço pago (custo unitário, R$)", type: "number", step: "0.01", required: true },
          { key: "markupPercent", label: "Quanto quero ganhar (% em cima do custo)", type: "number", step: "0.1", nullable: true, placeholder: "Ex.: 50" },
          { key: "salePrice", label: "Preço de venda (R$, 0 = uso interno)", type: "number", step: "0.01", required: true },
          { key: "minStock", label: "Estoque mínimo (alerta)", type: "number", step: "0.001", required: true },
          { key: "active", label: "Ativo", type: "checkbox" },
        ]}
        onFieldChange={productPricing}
        formExtra={(v) => <ProfitPreview cost={Number(v.costPrice) || 0} price={Number(v.salePrice) || 0} />}
        columns={[
          {
            label: "Produto",
            render: (p) => (
              <span className="flex items-center gap-2 font-medium">
                {p.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={p.photoUrl} alt="" className="h-9 w-9 rounded-lg object-cover" />
                ) : (
                  <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-zinc-100 text-xs text-zinc-400">📦</span>
                )}
                {p.name}
              </span>
            ),
          },
          {
            label: "Estoque",
            render: (p) => (
              <span className={p.lowStock ? "font-semibold text-brand-rose" : ""}>
                {p.stock} {p.unit} {p.lowStock && <Badge className="ml-1 bg-rose-100 text-rose-800">baixo</Badge>}
              </span>
            ),
          },
          { label: "Custo", render: (p) => formatMoney(p.costPrice), className: "hidden sm:table-cell" },
          { label: "Venda", render: (p) => (p.salePrice > 0 ? formatMoney(p.salePrice) : "—"), className: "hidden sm:table-cell" },
          {
            label: "Lucro por unidade",
            className: "hidden md:table-cell",
            render: (p) => (p.salePrice > 0 ? `${formatMoney(p.salePrice - p.costPrice)} (${markupOf(p.costPrice, p.salePrice)})` : "—"),
          },
        ]}
        rowActions={(p, reload) => (
          <Button variant="secondary" size="sm" onClick={() => setMoving({ product: p, reload })}>
            Movimentar
          </Button>
        )}
      />
      <MovementModal
        product={moving?.product ?? null}
        onClose={() => setMoving(null)}
        onSaved={() => {
          moving?.reload();
          setMoving(null);
        }}
      />
    </>
  );
}

function MovementModal({ product, onClose, onSaved }: { product: Product | null; onClose: () => void; onSaved: () => void }) {
  const [type, setType] = useState<MovementType>("IN");
  const [quantity, setQuantity] = useState("1");
  const [unitValue, setUnitValue] = useState("");
  const [error, setError] = useState<string>();
  const { data: history } = useApi<Movement[]>(product ? `/api/products/${product.id}/movements` : null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!product) return;
    setError(undefined);
    try {
      await api.post(`/api/products/${product.id}/movements`, {
        type,
        quantity: Number(quantity),
        unitValue: unitValue ? Number(unitValue) : null,
      });
      setQuantity("1");
      setUnitValue("");
      onSaved();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <Modal title={`Movimentar · ${product?.name ?? ""}`} open={!!product} onClose={onClose}>
      <form onSubmit={submit} className="space-y-3">
        <Select label="Tipo" value={type} onChange={(e) => setType(e.target.value as MovementType)}>
          {(Object.keys(MOVEMENT_LABEL) as MovementType[]).map((t) => (
            <option key={t} value={t}>
              {MOVEMENT_LABEL[t]}
            </option>
          ))}
        </Select>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Quantidade" type="number" step="0.001" min="0.001" required value={quantity} onChange={(e) => setQuantity(e.target.value)} />
          {(type === "IN" || type === "SALE") && (
            <Field
              label={type === "IN" ? "Custo unitário" : "Preço unitário"}
              type="number"
              step="0.01"
              min="0"
              placeholder={String(type === "IN" ? product?.costPrice : product?.salePrice)}
              value={unitValue}
              onChange={(e) => setUnitValue(e.target.value)}
            />
          )}
        </div>
        <ErrorMessage message={error} />
        <Button className="w-full">Registrar</Button>
      </form>

      {history && history.length > 0 && (
        <div className="mt-5">
          <p className="mb-2 text-sm font-medium text-zinc-700">Últimas movimentações</p>
          <ul className="divide-y text-sm">
            {history.map((m) => (
              <li key={m.id} className="flex justify-between py-1.5">
                <span>
                  {MOVEMENT_LABEL[m.type]} · {m.quantity}
                </span>
                <span className="text-zinc-500">{formatDateTime(m.createdAt)}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </Modal>
  );
}
