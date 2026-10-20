"use client";

import { useRef, useState } from "react";
import { Gallery } from "@/components/Gallery";
import { Button, Card, Empty, ErrorMessage, Field, Modal, PageHeader, Select } from "@/components/ui";
import { api } from "@/lib/api";
import type { Photo, PlanInfo, Professional, Service } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Portfólio: fotos dos trabalhos, que aparecem na página de agendamento e no app do cliente. */
export default function PortfolioPage() {
  const { data: photos, error, reload } = useApi<Photo[]>("/api/portfolio");
  const { data: services } = useApi<Service[]>("/api/services");
  const { data: professionals } = useApi<Professional[]>("/api/professionals");
  const { data: plan, reload: reloadPlan } = useApi<PlanInfo>("/api/salon/plan");
  const input = useRef<HTMLInputElement>(null);
  const [serviceId, setServiceId] = useState<number | null>(null);
  const [professionalId, setProfessionalId] = useState<number | null>(null);
  const [progress, setProgress] = useState<string>();
  const [uploadError, setUploadError] = useState<string>();
  const [editing, setEditing] = useState<Photo | null>(null);
  const [preview, setPreview] = useState(false);

  async function upload(files: FileList | null) {
    if (!files?.length) return;
    setUploadError(undefined);
    const list = Array.from(files);
    try {
      for (let i = 0; i < list.length; i++) {
        setProgress(`Enviando ${i + 1} de ${list.length}...`);
        const form = new FormData();
        form.append("file", list[i]);
        if (serviceId) form.append("serviceId", String(serviceId));
        if (professionalId) form.append("professionalId", String(professionalId));
        await api.upload<Photo>("/api/portfolio", form);
      }
    } catch (e) {
      setUploadError((e as Error).message);
    } finally {
      setProgress(undefined);
      if (input.current) input.current.value = "";
      reload();
      reloadPlan();
    }
  }

  async function move(index: number, delta: number) {
    if (!photos) return;
    const ids = photos.map((p) => p.id);
    const target = index + delta;
    if (target < 0 || target >= ids.length) return;
    [ids[index], ids[target]] = [ids[target], ids[index]];
    await api.put("/api/portfolio/order", { ids }).catch((e) => setUploadError((e as Error).message));
    reload();
  }

  async function remove(p: Photo) {
    if (!confirm("Apagar esta foto?")) return;
    await api.del(`/api/portfolio/${p.id}`).catch((e) => setUploadError((e as Error).message));
    reload();
    reloadPlan();
  }

  return (
    <>
      <PageHeader title="Portfólio">
        {photos && photos.length > 0 && (
          <Button variant="secondary" onClick={() => setPreview(!preview)}>
            {preview ? "Organizar" : "Ver como o cliente"}
          </Button>
        )}
      </PageHeader>
      <Card className="mb-4">
        <p className="mb-3 text-sm text-zinc-600">
          Fotos dos seus trabalhos aparecem na página de agendamento e no app do cliente. Envie JPG ou PNG; reduzimos o tamanho
          automaticamente.
          {plan?.photos && plan.photos.max > 0 && (
            <strong className="ml-1">
              {plan.photos.used} de {plan.photos.max} fotos.
            </strong>
          )}
        </p>
        <div className="grid gap-3 sm:grid-cols-3">
          <Select label="Serviço (opcional)" value={serviceId ?? ""} onChange={(e) => setServiceId(e.target.value ? Number(e.target.value) : null)}>
            <option value="">Nenhum</option>
            {services?.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </Select>
          <Select label="Profissional (opcional)" value={professionalId ?? ""} onChange={(e) => setProfessionalId(e.target.value ? Number(e.target.value) : null)}>
            <option value="">Nenhum</option>
            {professionals?.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </Select>
          <div className="flex items-end">
            <input ref={input} type="file" accept="image/jpeg,image/png" multiple className="hidden" onChange={(e) => upload(e.target.files)} />
            <Button className="w-full" disabled={!!progress} onClick={() => input.current?.click()}>
              {progress ?? "Enviar fotos"}
            </Button>
          </div>
        </div>
        <div className="mt-3">
          <ErrorMessage message={uploadError ?? error} />
        </div>
      </Card>

      {photos?.length === 0 && <Empty>Nenhuma foto ainda. Envie as fotos dos seus melhores trabalhos!</Empty>}
      {preview && photos ? (
        <Card>
          <Gallery photos={photos} />
        </Card>
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {photos?.map((p, i) => (
            <Card key={p.id} className="p-2">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={p.thumbUrl} alt={p.caption ?? ""} className="aspect-square w-full rounded-xl object-cover" />
              <p className="mt-2 truncate text-sm font-bold">{p.caption || <span className="font-normal text-zinc-400">Sem legenda</span>}</p>
              <p className="truncate text-xs text-zinc-500">{[p.serviceName, p.professionalName].filter(Boolean).join(" · ") || "—"}</p>
              <div className="mt-2 flex items-center justify-between gap-1">
                <div className="flex gap-1">
                  <Button size="sm" variant="ghost" disabled={i === 0} onClick={() => move(i, -1)} aria-label="Mover para antes">
                    ←
                  </Button>
                  <Button size="sm" variant="ghost" disabled={i === photos.length - 1} onClick={() => move(i, 1)} aria-label="Mover para depois">
                    →
                  </Button>
                </div>
                <div className="flex gap-1">
                  <Button size="sm" variant="secondary" onClick={() => setEditing(p)}>
                    Editar
                  </Button>
                  <Button size="sm" variant="danger" onClick={() => remove(p)} aria-label="Apagar">
                    ×
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      <EditPhoto
        photo={editing}
        services={services ?? []}
        professionals={professionals ?? []}
        onClose={() => setEditing(null)}
        onSaved={() => {
          setEditing(null);
          reload();
        }}
      />
    </>
  );
}

function EditPhoto({
  photo,
  services,
  professionals,
  onClose,
  onSaved,
}: {
  photo: Photo | null;
  services: Service[];
  professionals: Professional[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState({ caption: "", serviceId: "", professionalId: "" });
  const [error, setError] = useState<string>();
  const [loadedId, setLoadedId] = useState<number | null>(null);

  if (photo && loadedId !== photo.id) {
    setLoadedId(photo.id);
    setForm({ caption: photo.caption ?? "", serviceId: String(photo.serviceId ?? ""), professionalId: String(photo.professionalId ?? "") });
    setError(undefined);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!photo) return;
    try {
      await api.put(`/api/portfolio/${photo.id}`, {
        caption: form.caption,
        serviceId: form.serviceId ? Number(form.serviceId) : null,
        professionalId: form.professionalId ? Number(form.professionalId) : null,
      });
      onSaved();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <Modal title="Editar foto" open={!!photo} onClose={onClose}>
      <form onSubmit={save} className="space-y-3">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        {photo && <img src={photo.thumbUrl} alt="" className="mx-auto max-h-48 rounded-xl" />}
        <Field label="Legenda" maxLength={200} value={form.caption} onChange={(e) => setForm({ ...form, caption: e.target.value })} />
        <Select label="Serviço" value={form.serviceId} onChange={(e) => setForm({ ...form, serviceId: e.target.value })}>
          <option value="">Nenhum</option>
          {services.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </Select>
        <Select label="Profissional" value={form.professionalId} onChange={(e) => setForm({ ...form, professionalId: e.target.value })}>
          <option value="">Nenhum</option>
          {professionals.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </Select>
        <ErrorMessage message={error} />
        <Button className="w-full">Salvar</Button>
      </form>
    </Modal>
  );
}
