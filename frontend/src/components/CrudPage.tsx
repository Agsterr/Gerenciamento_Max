"use client";

import { useState } from "react";
import { Button, Card, Empty, ErrorMessage, Field, Modal, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useApi } from "@/lib/useApi";

export type FieldDef = {
  key: string;
  label: string;
  type?: "text" | "number" | "checkbox" | "tel" | "email";
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
  toolbar?: React.ReactNode;
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
  toolbar,
}: Props<T>) {
  const { user } = useAuth();
  const canEdit = !ownerOnly || user?.role === "OWNER";
  const { data, error, reload } = useApi<T[]>(listPath ?? path);
  const [editing, setEditing] = useState<Record<string, unknown> | null>(null);
  const [formError, setFormError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!editing) return;
    setBusy(true);
    setFormError(undefined);
    const body = { ...editing };
    for (const f of fields) if (f.type === "number") body[f.key] = Number(body[f.key]);
    try {
      if (editing.id) await api.put(`${path}/${editing.id}`, body);
      else await api.post(path, body);
      setEditing(null);
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
        {canEdit && <Button onClick={() => setEditing({ ...defaults })}>+ Novo</Button>}
      </PageHeader>
      <ErrorMessage message={error} />
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
                      <Button variant="ghost" size="sm" onClick={() => setEditing({ ...row })}>
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
              ) : (
                <Field
                  key={f.key}
                  label={f.label}
                  type={f.type ?? "text"}
                  step={f.step}
                  min={f.type === "number" ? 0 : undefined}
                  required={f.required}
                  placeholder={f.placeholder}
                  value={(editing[f.key] as string | number | null) ?? ""}
                  onChange={(e) => setEditing({ ...editing, [f.key]: e.target.value })}
                />
              ),
            )}
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
