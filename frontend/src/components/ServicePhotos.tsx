"use client";

/* eslint-disable @next/next/no-img-element */
import { useEffect, useMemo, useRef, useState } from "react";
import { ErrorMessage } from "@/components/ui";
import { api } from "@/lib/api";
import type { Photo } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Envia as fotos para o portfólio já ligadas ao serviço. */
export async function uploadServicePhotos(serviceId: number, files: File[], onProgress?: (text: string) => void) {
  for (let i = 0; i < files.length; i++) {
    onProgress?.(`Enviando ${i + 1} de ${files.length}...`);
    const form = new FormData();
    form.append("file", files[i]);
    form.append("serviceId", String(serviceId));
    await api.upload<Photo>("/api/portfolio", form);
  }
}

/**
 * Fotos de um serviço dentro do cadastro dele. Serviço novo: as fotos escolhidas esperam
 * (`files`) e são enviadas quando o serviço é salvo. Serviço existente: envia na hora.
 */
export function ServicePhotos({
  serviceId,
  files,
  onFiles,
}: {
  serviceId?: number;
  files: File[];
  onFiles: (files: File[]) => void;
}) {
  const { data: photos, reload } = useApi<Photo[]>(serviceId ? `/api/portfolio?serviceId=${serviceId}` : null);
  const input = useRef<HTMLInputElement>(null);
  const [progress, setProgress] = useState<string>();
  const [error, setError] = useState<string>();
  const previews = useMemo(() => files.map((f) => URL.createObjectURL(f)), [files]);
  useEffect(() => () => previews.forEach((u) => URL.revokeObjectURL(u)), [previews]);

  async function pick(list: FileList | null) {
    if (!list?.length) return;
    const chosen = Array.from(list);
    if (input.current) input.current.value = "";
    if (!serviceId) return onFiles([...files, ...chosen]);
    setError(undefined);
    try {
      await uploadServicePhotos(serviceId, chosen, setProgress);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setProgress(undefined);
      reload();
    }
  }

  async function remove(p: Photo) {
    if (!confirm("Apagar esta foto?")) return;
    await api.del(`/api/portfolio/${p.id}`).catch((e) => setError((e as Error).message));
    reload();
  }

  return (
    <div>
      <p className="text-sm font-semibold text-brand-ink">Fotos deste serviço</p>
      <p className="mb-2 text-xs text-zinc-500">
        {serviceId ? "Aparecem na página de agendamento e no app do cliente." : "Escolha agora; elas são enviadas quando você salvar o serviço."}
      </p>
      <div className="flex flex-wrap gap-2">
        <input ref={input} type="file" accept="image/jpeg,image/png" multiple className="hidden" onChange={(e) => pick(e.target.files)} />
        <button
          type="button"
          disabled={!!progress}
          onClick={() => input.current?.click()}
          className="flex h-20 w-20 flex-col items-center justify-center rounded-xl border-2 border-dashed border-brand-rose/60 bg-brand-rose/5 text-xs font-bold text-brand-rose disabled:opacity-60"
        >
          <span className="text-xl leading-none">+</span>
          {progress ? "..." : "Foto"}
        </button>
        {photos?.map((p) => (
          <Thumb key={p.id} src={p.thumbUrl} onRemove={() => remove(p)} />
        ))}
        {files.map((f, i) => (
          <Thumb key={`${f.name}-${i}`} src={previews[i]} onRemove={() => onFiles(files.filter((_, j) => j !== i))} />
        ))}
      </div>
      {progress && <p className="mt-1 text-xs text-zinc-500">{progress}</p>}
      <ErrorMessage message={error} />
    </div>
  );
}

function Thumb({ src, onRemove }: { src: string; onRemove: () => void }) {
  return (
    <div className="relative h-20 w-20">
      <img src={src} alt="" className="h-full w-full rounded-xl object-cover" />
      <button
        type="button"
        onClick={onRemove}
        aria-label="Remover foto"
        className="absolute right-1 top-1 flex h-5 w-5 items-center justify-center rounded-full bg-black/60 text-xs text-white"
      >
        ×
      </button>
    </div>
  );
}
