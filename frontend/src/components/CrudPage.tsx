"use client";

import { useState } from "react";
import { Button, Card, Empty, ErrorMessage, Field, Modal, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { ServicePhotos, uploadServicePhotos } from "@/components/ServicePhotos";
import { useAuth } from "@/lib/auth";
import { useApi } from "@/lib/useApi";
import type { Professional } from "@/lib/types";

export type FieldDef = {
  key: string;
  label: string;
  type?: "text" | "number" | "checkbox" | "tel" | "email" | "professionals" | "categories";
  /** Atalhos de preenchimento para campos de texto. */
  suggestions?: string[];
  hint?: string;
  /** Número opcional: vazio vai como null (em vez de 0). */
  nullable?: boolean;
  step?: string;
  required?: boolean;
  placeholder?: string;
};

export type ColumnDef<T> = { label: string; render: (row: T) => React.ReactNode; className?: string };

type Props<T extends { id: number }> = {
  title: string;
  path: string;
  fields: FieldDef[];
  columns: ColumnDef<T>[];
  defaults: Record<string, unknown>;
  /** Só o dono pode criar/editar (espelha a regra do backend). */
  ownerOnly?: boolean;
  rowActions?: (row: T, reload: () => void) => React.ReactNode;
  listPath?: string;
  /** Mostra só parte da lista (ex.: serviços sem os pacotes). */
  filter?: (row: T) => boolean;
  toolbar?: React.ReactNode;
  /** Mostra "Fotos deste serviço" no formulário (só para serviços). */
  servicePhotos?: boolean;
  /** Recalcula campos quando um muda (ex.: preço de venda a partir do custo e da margem). */
  onFieldChange?: (key: string, next: Record<string, unknown>) => Record<string, unknown>;
  /** Conteúdo extra no formulário (ex.: resumo do lucro). */
  formExtra?: (values: Record<string, unknown>) => React.ReactNode;
};

/** Tela padrão de cadastro: tabela + modal de criar/editar. */
export function CrudPage<T extends { id: number }>({
  title,
  path,
  fields,
  columns,
  defaults,
  ownerOnly,
  rowActions,
  listPath,
  filter,
  toolbar,
  servicePhotos,
  onFieldChange,
  formExtra,
}: Props<T>) {
  const { user } = useAuth();
  const canEdit = !ownerOnly || user?.role === "OWNER";
  const { data: all, error, reload } = useApi<T[]>(listPath ?? path);
  const data = filter ? all?.filter(filter) : all;
  const needsProfessionals = fields.some((f) => f.type === "professionals");
  const needsCategories = fields.some((f) => f.type === "categories");
  const { data: serviceCategories } = useApi<{ category: string | null }[]>(needsCategories ? "/api/services" : null);
  const { data: professionals } = useApi<Professional[]>(needsProfessionals ? "/api/professionals" : null);
  const [editing, setEditing] = useState<Record<string, unknown> | null>(null);
  const [formError, setFormError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const [files, setFiles] = useState<File[]>([]);
  const [notice, setNotice] = useState<string>();

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!editing) return;
    setBusy(true);
    setFormError(undefined);
    const body = { ...editing };
    for (const f of fields)
      if (f.type === "number") body[f.key] = f.nullable && (body[f.key] === "" || body[f.key] == null) ? null : Number(body[f.key]);
    try {
      if (editing.id) await api.put(`${path}/${editing.id}`, body);
      else {
        const created = await api.post<{ id: number }>(path, body);
        if (servicePhotos && files.length) {
          // o serviço já existe: se alguma foto falhar, avisa na página em vez de repetir o cadastro
          await uploadServicePhotos(created.id, files).catch((e) =>
            setNotice(`Serviço salvo, mas as fotos não foram enviadas: ${(e as Error).message}`),
          );
        }
      }
      setEditing(null);
      setFiles([]);
      reload();
    } catch (err) {
      setFormError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader title={title}>
        {toolbar}
        {canEdit && (
          <Button
            onClick={() => {
              setFiles([]);
              setNotice(undefined);
              setEditing({ ...defaults });
            }}
          >
            + Novo
          </Button>
        )}
      </PageHeader>
      <ErrorMessage message={error ?? notice} />
      <Card className="overflow-x-auto p-0">
        {data && data.length === 0 ? (
          <Empty>Nenhum registro ainda.</Empty>
        ) : (
          <table className="w-full text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-left text-zinc-500">
              <tr>
                {columns.map((c) => (
                  <th key={c.label} className={`px-4 py-2 font-medium ${c.className ?? ""}`}>
                    {c.label}
                  </th>
                ))}
                <th className="px-4 py-2" />
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {data?.map((row) => (
                <tr key={row.id} className="hover:bg-zinc-50">
                  {columns.map((c) => (
                    <td key={c.label} className={`px-4 py-2 ${c.className ?? ""}`}>
                      {c.render(row)}
                    </td>
                  ))}
                  <td className="whitespace-nowrap px-4 py-2 text-right">
                    {rowActions?.(row, reload)}
                    {canEdit && (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          setFiles([]);
                          setNotice(undefined);
                          setEditing({ ...row });
                        }}
                      >
                        Editar
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Modal title={editing?.id ? `Editar` : `Novo cadastro`} open={!!editing} onClose={() => setEditing(null)}>
        {editing && (
          <form onSubmit={save} className="space-y-3">
            {fields.map((f) =>
              f.type === "checkbox" ? (
                <label key={f.key} className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={Boolean(editing[f.key])}
                    onChange={(e) => setEditing({ ...editing, [f.key]: e.target.checked })}
                  />
                  {f.label}
                </label>
              ) : f.type === "categories" ? (
                <fieldset key={f.key}>
                  <legend className="mb-1 text-sm font-semibold text-brand-ink">{f.label}</legend>
                  <div className="flex flex-wrap gap-2">
                    {[
                      ...new Set([
                        ...(f.suggestions ?? []),
                        ...(serviceCategories?.map((s) => s.category).filter((c): c is string => !!c) ?? []),
                        ...((editing[f.key] as string[] | undefined) ?? []),
                      ]),
                    ].map((c) => {
                      const chosen = ((editing[f.key] as string[] | undefined) ?? []).includes(c);
                      return (
                        <button
                          key={c}
                          type="button"
                          onClick={() => {
                            const set = new Set((editing[f.key] as string[] | undefined) ?? []);
                            if (chosen) set.delete(c);
                            else set.add(c);
                            setEditing({ ...editing, [f.key]: [...set] });
                          }}
                          className={`rounded-full px-3 py-1.5 text-sm font-bold ${
                            chosen ? "bg-brand text-white" : "border border-[#F1E3EB] bg-white text-brand-muted"
                          }`}
                        >
                          {c}
                        </button>
                      );
                    })}
                  </div>
                  {f.hint && <p className="mt-1 text-xs text-zinc-500">{f.hint}</p>}
                </fieldset>
              ) : f.type === "professionals" ? (
                <fieldset key={f.key}>
                  <legend className="mb-1 text-sm font-semibold text-brand-ink">{f.label}</legend>
                  <div className="flex flex-wrap gap-2">
                    {professionals
                      ?.filter((p) => p.active)
                      .map((p) => {
                        const chosen = ((editing[f.key] as number[] | undefined) ?? []).includes(p.id);
                        return (
                          <button
                            key={p.id}
                            type="button"
                            onClick={() => {
                              const ids = new Set((editing[f.key] as number[] | undefined) ?? []);
                              if (chosen) ids.delete(p.id);
                              else ids.add(p.id);
                              setEditing({ ...editing, [f.key]: [...ids] });
                            }}
                            className={`rounded-full px-3 py-1.5 text-sm font-bold ${
                              chosen ? "bg-brand text-white" : "border border-[#F1E3EB] bg-white text-brand-muted"
                            }`}
                          >
                            {p.name}
                          </button>
                        );
                      })}
                  </div>
                  {f.hint && <p className="mt-1 text-xs text-zinc-500">{f.hint}</p>}
                </fieldset>
              ) : (
                <Field
                  key={f.key}
                  list={f.suggestions ? `${f.key}-options` : undefined}
                  label={f.label}
                  type={f.type ?? "text"}
                  step={f.step}
                  min={f.type === "number" ? 0 : undefined}
                  required={f.required}
                  placeholder={f.placeholder}
                  value={(editing[f.key] as string | number | null) ?? ""}
                  onChange={(e) => {
                    const next = { ...editing, [f.key]: e.target.value };
                    setEditing(onFieldChange ? onFieldChange(f.key, next) : next);
                  }}
                />
              ),
            )}
            {fields
              .filter((f) => f.suggestions)
              .map((f) => (
                <datalist key={f.key} id={`${f.key}-options`}>
                  {f.suggestions!.map((s) => (
                    <option key={s} value={s} />
                  ))}
                </datalist>
              ))}
            {formExtra?.(editing)}
            {servicePhotos && <ServicePhotos serviceId={editing.id as number | undefined} files={files} onFiles={setFiles} />}
            <ErrorMessage message={formError} />
            <Button className="w-full" disabled={busy}>
              {busy ? "Salvando..." : "Salvar"}
            </Button>
          </form>
        )}
      </Modal>
    </>
  );
}
