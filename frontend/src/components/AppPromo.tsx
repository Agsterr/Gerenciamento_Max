/* eslint-disable @next/next/no-img-element */
import { appDownloadUrl } from "@/lib/api";

/** Convite para o app do cliente nas páginas públicas do salão. */
export function AppPromo({ className = "" }: { className?: string }) {
  return (
    <a
      href={appDownloadUrl("cliente")}
      className={`shadow-soft flex items-center gap-4 rounded-2xl bg-white p-4 text-left transition hover:ring-2 hover:ring-brand-pink/40 ${className}`}
    >
      <img src="/icon-cliente.png" alt="" className="h-12 w-12 shrink-0 rounded-2xl" />
      <span className="min-w-0 flex-1">
        <span className="block font-extrabold">Prefere pelo app?</span>
        <span className="block text-sm text-brand-muted">
          Baixe o Salão Max (Android) e entre com o mesmo nome e WhatsApp para ver e remarcar seus horários.
        </span>
      </span>
      <span className="bg-brand shrink-0 rounded-xl px-3 py-2 text-sm font-extrabold text-white">Baixar</span>
    </a>
  );
}
