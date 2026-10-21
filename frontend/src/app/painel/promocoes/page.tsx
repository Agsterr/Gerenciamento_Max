"use client";

import { useEffect, useState } from "react";
import { Badge, Button, Card, Empty, ErrorMessage, Field, Modal, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { formatDate, formatMoney, isoDate } from "@/lib/format";
import type { Promotion, Service } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Pacotes (vários serviços com desconto) e promoções (desconto em % por um período). */
export default function PromotionsPage() {
  const { user } = useAuth();
  const canEdit = user?.role === "OWNER";
  const { data: services, reload: reloadServices } = useApi<Service[]>("/api/services");
  const { data: promos, reload: reloadPromos } = useApi<Promotion[]>("/api/promotions");
  const [kit, setKit] = useState<Partial<Service> | null>(null);
  const [promo, setPromo] = useState<Partial<Promotion> | null>(null);

  const plain = services?.filter((s) => s.kitServiceIds.length === 0 && s.active) ?? [];
  const kits = services?.filter((s) => s.kitServiceIds.length > 0) ?? [];
  const today = isoDate();

  return (
    <>
      <PageHeader title="Pacotes e promoções" />
      <p className="-mt-2 mb-6 max-w-2xl text-sm text-zinc-600">
        O cliente vê o preço promocional na página de agendamento e no app, com aviso das promoções. O desconto entra sozinho no
        agendamento e aparece no relatório.
      </p>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <div className="mb-3 flex items-center justify-between">
            <div>
              <h2 className="font-semibold">Pacotes (kits)</h2>
              <p className="text-sm text-zinc-500">Vários serviços juntos com desconto. Ex.: corte + escova + hidratação.</p>
            </div>
            {canEdit && (
              <Button size="sm" onClick={() => setKit({ name: "", kitServiceIds: [], kitDiscountPercent: 10, active: true })}>
                + Pacote
              </Button>
            )}
          </div>
          {kits.length === 0 ? (
            <Empty>Nenhum pacote ainda.</Empty>
          ) : (
            <ul className="divide-y text-sm">
              {kits.map((k) => (
                <li key={k.id} className="flex items-center justify-between gap-3 py-2.5">
                  <div className="min-w-0">
                    <p className="font-semibold">
                      {k.name} {!k.active && <Badge className="bg-zinc-200 text-zinc-600">inativo</Badge>}
                    </p>
                    <p className="text-zinc-500">
                      {services?.filter((s) => k.kitServiceIds.includes(s.id)).map((s) => s.name).join(" + ")} · {k.durationMinutes} min
                    </p>
                  </div>
                  <div className="text-right">
                    {k.kitFullPrice != null && <p className="text-xs text-zinc-400 line-through">{formatMoney(k.kitFullPrice)}</p>}
                    <p className="font-bold text-brand-rose">
                      {formatMoney(k.price)} <span className="text-xs text-emerald-700">-{k.kitDiscountPercent}%</span>
                    </p>
                    {canEdit && (
                      <Button variant="ghost" size="sm" onClick={() => setKit(k)}>
                        Editar
                      </Button>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card>
          <div className="mb-3 flex items-center justify-between">
            <div>
              <h2 className="font-semibold">Promoções</h2>
              <p className="text-sm text-zinc-500">Desconto em % para horários dentro do período.</p>
            </div>
            {canEdit && (
              <Button
                size="sm"
                onClick={() => setPromo({ name: "", discountPercent: 10, startsOn: today, endsOn: today, active: true, serviceIds: [] })}
              >
                + Promoção
              </Button>
            )}
          </div>
          {!promos || promos.length === 0 ? (
            <Empty>Nenhuma promoção ainda.</Empty>
          ) : (
            <ul className="divide-y text-sm">
              {promos.map((p) => {
                const status = !p.active ? "Pausada" : p.endsOn < today ? "Encerrada" : p.startsOn > today ? "Agendada" : "No ar";
                return (
                  <li key={p.id} className="flex items-center justify-between gap-3 py-2.5">
                    <div className="min-w-0">
                      <p className="font-semibold">
                        {p.name} · {p.discountPercent}%{" "}
                        <Badge
                          className={
                            status === "No ar" ? "bg-emerald-100 text-emerald-800" : status === "Agendada" ? "bg-amber-100 text-amber-800" : "bg-zinc-200 text-zinc-600"
                          }
                        >
                          {status}
                        </Badge>
                      </p>
                      <p className="text-zinc-500">
                        {formatDate(p.startsOn)} a {formatDate(p.endsOn)} · {p.serviceNames.length ? p.serviceNames.join(", ") : "Todos os serviços"}
                      </p>
                    </div>
                    {canEdit && (
                      <Button variant="ghost" size="sm" onClick={() => setPromo(p)}>
                        Editar
                      </Button>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </Card>
      </div>

      <KitModal
        kit={kit}
        services={plain}
        onClose={() => setKit(null)}
        onSaved={() => {
          setKit(null);
          reloadServices();
        }}
      />
      <PromoModal
        promo={promo}
        services={services?.filter((s) => s.active) ?? []}
        onClose={() => setPromo(null)}
        onSaved={() => {
          setPromo(null);
          reloadPromos();
        }}
      />
    </>
  );
}

function Chips({ options, value, onChange }: { options: Service[]; value: number[]; onChange: (ids: number[]) => void }) {
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((s) => {
        const on = value.includes(s.id);
        return (
          <button
            key={s.id}
            type="button"
            onClick={() => onChange(on ? value.filter((id) => id !== s.id) : [...value, s.id])}
            className={`rounded-full px-3 py-1.5 text-sm font-bold ${on ? "bg-brand text-white" : "border border-[#F1E3EB] bg-white text-brand-muted"}`}
          >
            {s.name} · {formatMoney(s.price)}
          </button>
        );
      })}
    </div>
  );
}

function KitModal({
  kit,
  services,
  onClose,
  onSaved,
}: {
  kit: Partial<Service> | null;
  services: Service[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState<Partial<Service> | null>(null);
  const [error, setError] = useState<string>();
  useEffect(() => {
    setForm(kit);
    setError(undefined);
  }, [kit]);
  const f = form;
  const chosen = services.filter((s) => f?.kitServiceIds?.includes(s.id));
  const full = chosen.reduce((t, s) => t + s.price, 0);
  const pct = Number(f?.kitDiscountPercent ?? 0);
  const price = Math.round(full * (100 - pct)) / 100;
  const minutes = chosen.reduce((t, s) => t + s.durationMinutes, 0);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!f) return;
    setError(undefined);
    const body = {
      name: f.name,
      description: f.description ?? null,
      category: f.category ?? "Pacotes",
      durationMinutes: Math.max(minutes, 5),
      price,
      cost: 0,
      active: f.active ?? true,
      professionalIds: f.professionalIds ?? [],
      kitServiceIds: f.kitServiceIds,
      kitDiscountPercent: pct,
    };
    try {
      if (f.id) await api.put(`/api/services/${f.id}`, body);
      else await api.post("/api/services", body);
      setForm(null);
      onSaved();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <Modal
      title={f?.id ? "Editar pacote" : "Novo pacote"}
      open={!!kit}
      onClose={() => {
        setForm(null);
        onClose();
      }}
    >
      {f && (
        <form onSubmit={save} className="space-y-3">
          <Field label="Nome do pacote" required value={f.name ?? ""} placeholder="Dia da noiva" onChange={(e) => setForm({ ...f, name: e.target.value })} />
          <div>
            <p className="mb-1 text-sm font-semibold text-brand-ink">Serviços do pacote (pelo menos 2)</p>
            <Chips options={services} value={f.kitServiceIds ?? []} onChange={(ids) => setForm({ ...f, kitServiceIds: ids })} />
          </div>
          <Field
            label="Desconto do pacote (%)"
            type="number"
            min={0}
            max={90}
            step="0.5"
            value={f.kitDiscountPercent ?? 0}
            onChange={(e) => setForm({ ...f, kitDiscountPercent: Number(e.target.value) })}
          />
          <div className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800">
            Separado: {formatMoney(full)} · <strong>Pacote: {formatMoney(price)}</strong> · cliente economiza {formatMoney(full - price)} · {minutes} min
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={f.active ?? true} onChange={(e) => setForm({ ...f, active: e.target.checked })} />
            Ativo (aparece no agendamento)
          </label>
          <ErrorMessage message={error} />
          <Button className="w-full" disabled={chosen.length < 2}>
            Salvar
          </Button>
        </form>
      )}
    </Modal>
  );
}

function PromoModal({
  promo,
  services,
  onClose,
  onSaved,
}: {
  promo: Partial<Promotion> | null;
  services: Service[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState<Partial<Promotion> | null>(null);
  const [error, setError] = useState<string>();
  useEffect(() => {
    setForm(promo);
    setError(undefined);
  }, [promo]);
  const f = form;

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!f) return;
    setError(undefined);
    const body = { ...f, discountPercent: Number(f.discountPercent) };
    try {
      if (f.id) await api.put(`/api/promotions/${f.id}`, body);
      else await api.post("/api/promotions", body);
      setForm(null);
      onSaved();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function remove() {
    if (!f?.id || !confirm("Excluir esta promoção?")) return;
    await api.del(`/api/promotions/${f.id}`);
    setForm(null);
    onSaved();
  }

  return (
    <Modal
      title={f?.id ? "Editar promoção" : "Nova promoção"}
      open={!!promo}
      onClose={() => {
        setForm(null);
        onClose();
      }}
    >
      {f && (
        <form onSubmit={save} className="space-y-3">
          <Field label="Nome" required value={f.name ?? ""} placeholder="Semana da escova" onChange={(e) => setForm({ ...f, name: e.target.value })} />
          <Field label="Descrição (aparece para o cliente)" value={f.description ?? ""} onChange={(e) => setForm({ ...f, description: e.target.value })} />
          <Field
            label="Desconto (%)"
            type="number"
            min={1}
            max={90}
            step="0.5"
            required
            value={f.discountPercent ?? ""}
            onChange={(e) => setForm({ ...f, discountPercent: Number(e.target.value) })}
          />
          <div className="grid grid-cols-2 gap-2">
            <Field label="Começa em" type="date" required value={f.startsOn ?? ""} onChange={(e) => setForm({ ...f, startsOn: e.target.value })} />
            <Field label="Termina em" type="date" required value={f.endsOn ?? ""} onChange={(e) => setForm({ ...f, endsOn: e.target.value })} />
          </div>
          <div>
            <p className="mb-1 text-sm font-semibold text-brand-ink">Serviços (nenhum marcado = todos, menos pacotes)</p>
            <Chips options={services} value={f.serviceIds ?? []} onChange={(ids) => setForm({ ...f, serviceIds: ids })} />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={f.active ?? true} onChange={(e) => setForm({ ...f, active: e.target.checked })} />
            Ativa
          </label>
          <ErrorMessage message={error} />
          <Button className="w-full">Salvar</Button>
          {f.id && (
            <Button type="button" variant="ghost" className="w-full text-rose-700" onClick={remove}>
              Excluir promoção
            </Button>
          )}
        </form>
      )}
    </Modal>
  );
}
