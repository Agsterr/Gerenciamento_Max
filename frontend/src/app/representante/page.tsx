"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Badge, Button, Card, Empty, ErrorMessage, Field, Stat } from "@/components/ui";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { formatCents, formatDate } from "@/lib/format";
import type { RepDashboard } from "@/lib/types";
import { useApi } from "@/lib/useApi";

const SALON_STATUS = {
  PAGANDO: ["Pagando", "bg-emerald-100 text-emerald-800"],
  TESTE: ["Em teste grátis", "bg-amber-100 text-amber-800"],
  VENCIDO: ["Plano vencido", "bg-zinc-200 text-zinc-700"],
} as const;

const COMMISSION_STATUS = {
  PENDING: ["Em espera", "bg-amber-100 text-amber-800"],
  AVAILABLE: ["Disponível", "bg-sky-100 text-sky-800"],
  PAID: ["Pago", "bg-emerald-100 text-emerald-800"],
  REVERSED: ["Estornado", "bg-rose-100 text-rose-800"],
} as const;

/** Painel do representante: link de indicação, salões indicados e o que ele tem a receber. */
export default function RepresentativePage() {
  const { user, ready, signOut } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (ready && !user) router.replace("/login");
    else if (ready && user && user.role !== "REPRESENTATIVE") router.replace(user.role === "PLATFORM_ADMIN" ? "/plataforma" : "/painel");
  }, [ready, user, router]);

  if (!user || user.role !== "REPRESENTATIVE") return <p className="p-8 text-center text-zinc-500">Carregando...</p>;

  return (
    <div className="min-h-screen">
      <header className="border-b border-zinc-200 bg-white">
        <div className="mx-auto flex max-w-4xl items-center justify-between gap-3 px-4 py-3">
          <Link href="/representante" className="flex items-center gap-2 text-lg font-extrabold">
            <span className="text-brand">Salão Max</span>
            <span className="text-sm font-bold text-brand-muted">Representante</span>
          </Link>
          <div className="flex items-center gap-3 text-sm">
            <span className="hidden text-zinc-600 sm:inline">{user.name}</span>
            <button
              onClick={() => {
                signOut();
                router.push("/login");
              }}
              className="text-zinc-500 hover:text-brand-rose"
            >
              Sair
            </button>
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-4xl space-y-5 p-4 md:p-8">
        <Dashboard />
      </main>
    </div>
  );
}

function Dashboard() {
  const { data: d, error, reload } = useApi<RepDashboard>("/api/representative/me");
  const [copied, setCopied] = useState(false);
  const [pix, setPix] = useState<string>();
  const [pixMsg, setPixMsg] = useState<string>();
  const [copiedKey, setCopiedKey] = useState<string>();

  if (error) return <ErrorMessage message={error} />;
  if (!d) return <p className="text-center text-zinc-500">Carregando...</p>;

  const share = `Conheça o Salão Max: agenda e agendamento online para salão de beleza. Veja como funciona e teste grátis: ${d.link}`;
  const base = (() => {
    try {
      return new URL(d.link).origin;
    } catch {
      return "";
    }
  })();
  const materials = [
    {
      key: "apresentacao",
      title: "Apresentação do Salão Max (para donos de salão)",
      text: "Explica como o aplicativo funciona, a versão web e o app, os preços e o teste grátis. O botão de assinar já leva o seu código.",
      url: d.link,
      msg: `Conheça o Salão Max: veja como funciona e teste grátis. ${d.link}`,
    },
    {
      key: "cliente",
      title: "Como o cliente do salão agenda",
      text: "Passo a passo para quem vai agendar no salão. Serve para o dono mostrar aos clientes dele.",
      url: `${d.link}#cliente`,
      msg: `Veja como é fácil agendar seu horário no salão, em 1 minuto: ${d.link}#cliente`,
    },
    {
      key: "cadastro",
      title: "Cadastro direto (sem apresentação)",
      text: "Leva direto para criar o salão, com o seu código. Use com quem já conhece o aplicativo.",
      url: `${base}/cadastro?ref=${d.code}`,
      msg: `Crie seu salão no Salão Max e teste grátis: ${base}/cadastro?ref=${d.code}`,
    },
  ];
  const pixValue = pix ?? d.pixKey ?? "";

  async function copy() {
    try {
      await navigator.clipboard.writeText(d!.link);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      window.prompt("Copie o link:", d!.link);
    }
  }

  async function copyLink(key: string, url: string) {
    try {
      await navigator.clipboard.writeText(url);
      setCopiedKey(key);
      setTimeout(() => setCopiedKey(undefined), 2000);
    } catch {
      window.prompt("Copie o link:", url);
    }
  }

  async function savePix() {
    setPixMsg(undefined);
    try {
      await api.put("/api/representative/pix", { pixKey: pixValue });
      setPixMsg("Chave Pix salva.");
      reload();
    } catch (e) {
      setPixMsg((e as Error).message);
    }
  }

  return (
    <>
      <Card className="bg-night !text-white">
        <p className="text-sm font-semibold opacity-80">Seu link de indicação</p>
        <p className="mt-1 break-all text-lg font-extrabold">{d.link}</p>
        <p className="mt-1 text-sm opacity-80">
          Código <b>{d.code}</b> · cada mensalidade paga de um salão indicado gera {formatCents(d.commissionCents)} para você.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Button onClick={copy}>{copied ? "Copiado!" : "Copiar link"}</Button>
          <a
            href={`https://wa.me/?text=${encodeURIComponent(share)}`}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl bg-white px-4 py-2 font-bold text-zinc-800"
          >
            Enviar pelo WhatsApp
          </a>
        </div>
      </Card>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label="Disponível para receber" value={formatCents(d.totals.availableCents)} hint="já passou do prazo de estorno" />
        <Stat label="Em espera" value={formatCents(d.totals.releasingCents)} hint={`libera ${d.holdDays} dias após o pagamento`} />
        <Stat label="Já recebido" value={formatCents(d.totals.paidCents)} />
        <Stat label="Perdido por estorno" value={formatCents(d.totals.reversedCents)} />
      </div>

      <Card>
        <details>
        <summary className="cursor-pointer font-extrabold text-brand-ink">Materiais para enviar</summary>
        <p className="mb-3 mt-2 text-sm text-zinc-600">
          Seu link de indicação já abre uma apresentação do aplicativo antes do cadastro, e o seu código segue sozinho. Escolha o que mandar:
        </p>
        <div className="space-y-3">
          {materials.map((m) => (
            <div key={m.key} className="rounded-2xl border border-zinc-200 p-4">
              <p className="font-bold text-brand-ink">{m.title}</p>
              <p className="mt-1 text-sm text-zinc-600">{m.text}</p>
              <p className="mt-2 break-all rounded-xl bg-zinc-50 px-3 py-2 text-sm font-semibold text-zinc-800">{m.url}</p>
              <div className="mt-2 flex flex-wrap gap-2">
                <Button onClick={() => copyLink(m.key, m.url)}>{copiedKey === m.key ? "Copiado!" : "Copiar link"}</Button>
                <a
                  href={`https://wa.me/?text=${encodeURIComponent(m.msg)}`}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-xl bg-emerald-600 px-4 py-2 font-bold text-white"
                >
                  WhatsApp
                </a>
                <a href={m.url} target="_blank" rel="noreferrer" className="rounded-xl bg-zinc-100 px-4 py-2 font-bold text-zinc-800">
                  Ver como fica
                </a>
              </div>
            </div>
          ))}
        </div>
        </details>
      </Card>

      <Card>
        <h2 className="mb-2 font-extrabold text-brand-ink">Como você recebe</h2>
        <p className="mb-3 text-sm text-zinc-600">
          O Salão Max faz o Pix das comissões disponíveis na chave abaixo. Comissão de pagamento estornado ou contestado é perdida;
          se o salão apenas cancelar, o que já foi pago continua seu e só os meses seguintes deixam de contar.
        </p>
        <div className="flex flex-wrap items-end gap-2">
          <Field label="Sua chave Pix" placeholder="CPF, e-mail, telefone ou chave aleatória" className="min-w-0 flex-1" value={pixValue} onChange={(e) => setPix(e.target.value)} />
          <Button onClick={savePix}>Salvar</Button>
        </div>
        {pixMsg && <p className="mt-2 text-sm text-zinc-600">{pixMsg}</p>}
      </Card>

      <Card>
        <h2 className="mb-2 font-extrabold text-brand-ink">Salões que você indicou ({d.salons.length})</h2>
        {d.salons.length === 0 ? (
          <Empty>Ninguém se cadastrou pelo seu link ainda. Compartilhe o link acima.</Empty>
        ) : (
          <ul className="divide-y divide-zinc-100">
            {d.salons.map((s) => {
              const [label, cls] = SALON_STATUS[s.status];
              return (
                <li key={s.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                  <div>
                    <p className="font-bold">{s.name}</p>
                    <p className="text-xs text-zinc-500">Cadastrado em {formatDate(s.createdAt)}</p>
                  </div>
                  <div className="text-right">
                    <Badge className={cls}>{label}</Badge>
                    <p className="mt-1 text-xs text-zinc-500">
                      {s.paidMonths} {s.paidMonths === 1 ? "mês pago" : "meses pagos"} · {formatCents(s.earnedCents)}
                    </p>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Card>

      <Card>
        <h2 className="mb-2 font-extrabold text-brand-ink">Comissões</h2>
        {d.commissions.length === 0 ? (
          <Empty>Quando um salão indicado pagar a mensalidade, a comissão aparece aqui.</Empty>
        ) : (
          <ul className="divide-y divide-zinc-100">
            {d.commissions.map((c) => {
              // pendente com o prazo de estorno vencido já está disponível para o repasse
              const key = c.status === "PENDING" && new Date(c.availableAt) <= new Date() ? "AVAILABLE" : c.status;
              const [label, cls] = COMMISSION_STATUS[key];
              return (
                <li key={c.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                  <div>
                    <p className="font-bold">{c.salonName}</p>
                    <p className="text-xs text-zinc-500">
                      Pago em {formatDate(c.createdAt)}
                      {c.status === "PENDING" && ` · disponível em ${formatDate(c.availableAt)}`}
                    </p>
                  </div>
                  <div className="ml-auto text-right">
                    <p className={`font-extrabold ${c.status === "REVERSED" ? "text-zinc-400 line-through" : ""}`}>{formatCents(c.amountCents)}</p>
                    <Badge className={cls}>{label}</Badge>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Card>
    </>
  );
}
