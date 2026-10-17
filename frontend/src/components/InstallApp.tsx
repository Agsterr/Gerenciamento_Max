"use client";

/* eslint-disable @next/next/no-img-element */
import { useState } from "react";
import { Modal } from "@/components/ui";
import { appDownloadUrl } from "@/lib/api";
import { useInstallApp } from "@/lib/pwa";

const NAMES = { gestao: "app do salão", cliente: "app" } as const;

/** Passo a passo do iPhone/iPad: o Safari não tem botão de instalar, só "Adicionar à Tela de Início". */
function IosSteps({ open, onClose }: { open: boolean; onClose: () => void }) {
  return (
    <Modal title="Instalar no iPhone" open={open} onClose={onClose}>
      <ol className="list-decimal space-y-2 pl-5 text-brand-ink">
        <li>
          Abra este site no <strong>Safari</strong>.
        </li>
        <li>
          Toque em <strong>Compartilhar</strong> (o quadrado com a seta para cima, na barra de baixo).
        </li>
        <li>
          Escolha <strong>Adicionar à Tela de Início</strong> e toque em <strong>Adicionar</strong>.
        </li>
      </ol>
      <p className="mt-4 text-sm text-brand-muted">Pronto: o ícone aparece junto dos outros apps e abre em tela cheia.</p>
    </Modal>
  );
}

/**
 * "Instalar app": instala o PWA direto (Android/Chrome), mostra o passo a passo no iPhone,
 * ou cai no APK quando o navegador não oferece instalação.
 */
export function InstallAppLink({ app, className = "" }: { app: "gestao" | "cliente"; className?: string }) {
  const { canInstall, ios, installed, install } = useInstallApp();
  const [steps, setSteps] = useState(false);
  if (installed) return null;
  const label = `Instalar ${NAMES[app]}`;
  if (canInstall)
    return (
      <button type="button" onClick={install} className={`text-left ${className}`}>
        {label}
      </button>
    );
  if (ios)
    return (
      <>
        <button type="button" onClick={() => setSteps(true)} className={`text-left ${className}`}>
          {label}
        </button>
        <IosSteps open={steps} onClose={() => setSteps(false)} />
      </>
    );
  return (
    <a href={appDownloadUrl(app)} className={className}>
      Baixar {NAMES[app]} (Android)
    </a>
  );
}

/** Convite para o app nas páginas públicas do salão (some quando já está aberto como app). */
export function AppPromo({ className = "" }: { className?: string }) {
  const { canInstall, ios, android, installed, install } = useInstallApp();
  const [steps, setSteps] = useState(false);
  if (installed) return null;

  const action = canInstall ? (
    <button onClick={install} className="bg-brand shrink-0 rounded-xl px-3 py-2 text-sm font-extrabold text-white">
      Instalar
    </button>
  ) : ios ? (
    <button onClick={() => setSteps(true)} className="bg-brand shrink-0 rounded-xl px-3 py-2 text-sm font-extrabold text-white">
      Como instalar
    </button>
  ) : (
    <a href={appDownloadUrl("cliente")} className="bg-brand shrink-0 rounded-xl px-3 py-2 text-sm font-extrabold text-white">
      Baixar
    </a>
  );

  return (
    <div className={`shadow-soft rounded-2xl bg-white p-4 ${className}`}>
      <div className="flex items-center gap-4">
        <img src="/pwa/cliente-192.png" alt="" className="h-12 w-12 shrink-0 rounded-2xl" />
        <span className="min-w-0 flex-1">
          <span className="block font-extrabold">Tenha o salão na tela do celular</span>
          <span className="block text-sm text-brand-muted">
            Instale o app e entre com o mesmo nome e WhatsApp para ver e remarcar seus horários.
          </span>
        </span>
        {action}
      </div>
      {canInstall && android && (
        <a href={appDownloadUrl("cliente")} className="mt-2 block text-right text-xs font-semibold text-brand-muted underline">
          ou baixe o APK do Salão Max
        </a>
      )}
      <IosSteps open={steps} onClose={() => setSteps(false)} />
    </div>
  );
}
