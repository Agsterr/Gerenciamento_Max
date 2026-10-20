"use client";

import { useEffect, useRef, useState } from "react";
import type { Photo } from "@/lib/types";

/** Grade de miniaturas; tocar abre a foto em tela cheia (setas, deslizar e Esc). */
export function Gallery({ photos, className = "" }: { photos: Photo[]; className?: string }) {
  const [open, setOpen] = useState<number | null>(null);
  if (photos.length === 0) return null;
  return (
    <>
      <div className={`grid grid-cols-3 gap-1.5 sm:gap-2 ${className}`}>
        {photos.map((p, i) => (
          <button
            key={p.id}
            onClick={() => setOpen(i)}
            className="relative aspect-square overflow-hidden rounded-xl bg-[#F6EEF3] focus:outline-none focus:ring-4 focus:ring-brand-pink/30"
            aria-label={p.caption ?? "Abrir foto"}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={p.thumbUrl} alt={p.caption ?? ""} loading="lazy" className="h-full w-full object-cover transition hover:scale-105" />
          </button>
        ))}
      </div>
      {open !== null && <Lightbox photos={photos} index={open} onIndex={setOpen} onClose={() => setOpen(null)} />}
    </>
  );
}

function Lightbox({
  photos,
  index,
  onIndex,
  onClose,
}: {
  photos: Photo[];
  index: number;
  onIndex: (i: number) => void;
  onClose: () => void;
}) {
  const touchX = useRef<number | null>(null);
  const photo = photos[index];
  const go = (delta: number) => onIndex((index + delta + photos.length) % photos.length);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowRight") onIndex((index + 1) % photos.length);
      if (e.key === "ArrowLeft") onIndex((index - 1 + photos.length) % photos.length);
    };
    window.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [index, photos.length, onIndex, onClose]);

  const subtitle = [photo.serviceName, photo.professionalName && `por ${photo.professionalName}`].filter(Boolean).join(" · ");

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col bg-black/95 text-white"
      onClick={onClose}
      onTouchStart={(e) => (touchX.current = e.touches[0].clientX)}
      onTouchEnd={(e) => {
        if (touchX.current === null) return;
        const dx = e.changedTouches[0].clientX - touchX.current;
        touchX.current = null;
        if (Math.abs(dx) > 50) go(dx < 0 ? 1 : -1);
      }}
      role="dialog"
      aria-modal="true"
    >
      <div className="flex items-center justify-between px-4 py-3 text-sm">
        <span className="text-white/70">
          {index + 1} / {photos.length}
        </span>
        <button onClick={onClose} className="text-3xl leading-none text-white/80 hover:text-white" aria-label="Fechar">
          ×
        </button>
      </div>
      <div className="relative flex min-h-0 flex-1 items-center justify-center px-2" onClick={(e) => e.stopPropagation()}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={photo.url} alt={photo.caption ?? ""} className="max-h-full max-w-full rounded-lg object-contain" />
        {photos.length > 1 && (
          <>
            <button onClick={() => go(-1)} className="absolute left-2 top-1/2 hidden -translate-y-1/2 rounded-full bg-white/15 px-3 py-2 text-2xl sm:block" aria-label="Anterior">
              ‹
            </button>
            <button onClick={() => go(1)} className="absolute right-2 top-1/2 hidden -translate-y-1/2 rounded-full bg-white/15 px-3 py-2 text-2xl sm:block" aria-label="Próxima">
              ›
            </button>
          </>
        )}
      </div>
      <div className="min-h-16 px-4 py-3 text-center" onClick={(e) => e.stopPropagation()}>
        {photo.caption && <p className="font-semibold">{photo.caption}</p>}
        {subtitle && <p className="text-sm text-white/70">{subtitle}</p>}
      </div>
    </div>
  );
}
