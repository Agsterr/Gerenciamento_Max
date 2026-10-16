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

export default function ProductsPage() {
  const [moving, setMoving] = useState<{ product: Product; reload: () => void } | null>(null);

  return (
    <>
      <CrudPage<Product>
        title="Produtos e estoque"
        path="/api/products"
        defaults={{ name: "", costPrice: 0, salePrice: 0, minStock: 0, unit: "un", active: true }}
        fields={[
          { key: "name", label: "Nome", required: true },
          { key: "unit", label: "Unidade (un, ml, g...)", required: true },
          { key: "costPrice", label: "Custo unitário (R$)", type: "number", step: "0.01", required: true },
          { key: "salePrice", label: "Preço de venda (R$, 0 = uso interno)", type: "number", step: "0.01", required: true },
          { key: "minStock", label: "Estoque mínimo (alerta)", type: "number", step: "0.001", required: true },
          { key: "active", label: "Ativo", type: "checkbox" },
        ]}
        columns={[
          { label: "Produto", render: (p) => <span className="font-medium">{p.name}</span> },
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
