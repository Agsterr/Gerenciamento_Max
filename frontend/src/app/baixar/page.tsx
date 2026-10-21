/* eslint-disable @next/next/no-img-element */
import type { Metadata } from "next";
import Link from "next/link";
import { Icon } from "@/components/Icon";
import { appDownloadUrl } from "@/lib/api";

export const metadata: Metadata = {
  title: "Baixar os apps — Salão Max",
  description: "Instale o Salão Max (clientes) e o Salão Max Gestão (salão) no Android.",
};

const APPS = [
  {
    id: "gestao" as const,
    icon: "/icon-gestao.png",
    name: "Salão Max Gestão",
    who: "Para o salão",
    text: "Agenda de cada profissional, serviços com fotos, clientes, produtos e financeiro no celular. Entre com o mesmo e-mail e senha do painel e marque “Manter conectado”.",
  },
  {
    id: "cliente" as const,
    icon: "/icon-cliente.png",
    name: "Salão Max",
    who: "Para clientes",
    text: "Encontre seu salão e agende em 1 minuto. Os salões que você já usou ficam salvos: toque no salão para ver seus horários. Entre só com nome e WhatsApp, sem senha.",
  },
];

export default function DownloadPage() {
  return (
    <main className="bg-night min-h-screen px-4 py-10 text-white">
      <div className="mx-auto max-w-3xl">
        <Link href="/" className="flex items-center gap-2 font-extrabold">
          <img src="/icon-cliente.png" alt="" className="h-9 w-9 rounded-xl" />
          Salão Max
        </Link>
        <h1 className="mt-10 text-3xl font-extrabold tracking-tight sm:text-4xl">Baixe os apps</h1>
        <p className="mt-2 text-white/75">
          Instalação direta no Android. Os apps avisam sozinhos quando sai uma versão nova.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2">
          {APPS.map((app) => (
            <div key={app.id} className="rounded-3xl bg-white p-6 text-brand-ink shadow-soft">
              <img src={app.icon} alt="" className="h-14 w-14 rounded-2xl" />
              <p className="mt-4 text-sm font-extrabold uppercase tracking-widest text-brand-rose">{app.who}</p>
              <h2 className="text-xl font-extrabold">{app.name}</h2>
              <p className="mt-1 text-brand-muted">{app.text}</p>
              <a
                href={appDownloadUrl(app.id)}
                className="bg-brand shadow-glow mt-5 inline-flex items-center gap-2 rounded-2xl px-5 py-3 font-bold text-white"
              >
                Baixar APK <Icon name="arrow" />
              </a>
            </div>
          ))}
        </div>

        <div className="mt-8 rounded-3xl bg-white/10 p-6 text-sm text-white/80 ring-1 ring-white/15">
          <p className="flex items-center gap-2 font-bold text-white">
            <Icon name="shield" className="h-5 w-5 text-emerald-300" /> Como instalar
          </p>
          <ol className="mt-2 list-decimal space-y-1 pl-5">
            <li>Toque em “Baixar APK” e abra o arquivo baixado.</li>
            <li>Se o Android pedir, permita instalar apps desta fonte (só na primeira vez).</li>
            <li>Toque em “Instalar”. Pronto!</li>
          </ol>
          <p className="mt-3 font-bold text-white">iPhone ou sem baixar nada</p>
          <p className="mt-1">
            Os dois apps também instalam direto pelo site (PWA). No Android, toque em “Instalar app”. No iPhone, abra no Safari,
            toque em Compartilhar e em “Adicionar à Tela de Início” — o salão no painel, e o cliente no link de agendamento do salão.
          </p>
          <p className="mt-3">Prefere usar no computador? O painel funciona direto no navegador.</p>
        </div>
      </div>
    </main>
  );
}
