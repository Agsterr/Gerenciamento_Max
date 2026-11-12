"use client";

/* eslint-disable @next/next/no-img-element */
import Link from "next/link";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { Icon } from "@/components/Icon";
import { PhoneFrame } from "@/components/PhoneFrame";

/** Apresentação digital do Salão Max: um link só, três públicos (salão, cliente e representante). */
export type Audience = "salao" | "cliente" | "representante";

const PRICE_SITE = "49,90";
const PRICE_PLAY = "58,90";
const COMMISSION = 15;
const TRIAL_DAYS = 14;
const SITE = "salaomax.focodev.com.br";
/** Passe para true quando os apps estiverem publicados na Google Play. */
const PLAY_LIVE = false;
const REF_KEY = "salao.ref";

const TABS: { id: Audience; label: string; short: string; icon: string }[] = [
  { id: "salao", label: "Sou dono de salão", short: "Salão", icon: "scissors" },
  { id: "cliente", label: "Sou cliente", short: "Cliente", icon: "smile" },
  { id: "representante", label: "Quero indicar e ganhar", short: "Representante", icon: "hand" },
];

const money = (n: number) => n.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

async function copyText(text: string) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

/* ───────────── peças reutilizáveis ───────────── */

function Reveal({ children, className = "", delay = 0 }: { children: ReactNode; className?: string; delay?: number }) {
  const ref = useRef<HTMLDivElement>(null);
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (typeof IntersectionObserver === "undefined") {
      setShown(true);
      return;
    }
    const io = new IntersectionObserver(
      ([e]) => {
        if (e.isIntersecting) {
          setShown(true);
          io.disconnect();
        }
      },
      { threshold: 0.1 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);
  return (
    <div ref={ref} style={{ transitionDelay: `${delay}ms` }} className={`reveal ${shown ? "in" : ""} ${className}`}>
      {children}
    </div>
  );
}

function Head({ kicker, title, text }: { kicker: string; title: string; text?: string }) {
  return (
    <div className="mx-auto max-w-2xl text-center">
      <p className="text-sm font-extrabold uppercase tracking-widest text-brand-rose">{kicker}</p>
      <h2 className="mt-2 text-3xl font-extrabold tracking-tight sm:text-4xl">{title}</h2>
      {text && <p className="mt-3 text-brand-muted">{text}</p>}
    </div>
  );
}

function Faq({ items }: { items: [string, string][] }) {
  return (
    <div className="mx-auto mt-10 max-w-3xl space-y-3">
      {items.map(([q, a]) => (
        <details key={q} className="group shadow-soft rounded-2xl bg-white p-5 open:ring-2 open:ring-brand-rose/30">
          <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-extrabold">
            {q}
            <span className="bg-brand flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-lg leading-none text-white transition group-open:rotate-45">
              +
            </span>
          </summary>
          <p className="mt-3 text-brand-muted">{a}</p>
        </details>
      ))}
    </div>
  );
}

function PhonePair({
  a,
  b,
}: {
  a: { src: string; top: string; alt: string };
  b: { src: string; top: string; alt: string };
}) {
  return (
    <div className="relative mx-auto w-full max-w-md pb-10 lg:h-[36rem] lg:pb-0">
      <div className="flex items-end justify-center gap-3 lg:block">
        <PhoneFrame
          {...a}
          eager
          className="float-slow w-[47%] -rotate-3 lg:absolute lg:-bottom-24 lg:left-0 lg:w-[58%] lg:-rotate-6"
        />
        <PhoneFrame
          {...b}
          eager
          className="float-slow-2 mb-6 w-[47%] rotate-3 lg:absolute lg:-bottom-10 lg:right-0 lg:mb-0 lg:w-[58%]"
        />
      </div>
    </div>
  );
}

function CtaButton({ href, children, variant = "solid" }: { href: string; children: ReactNode; variant?: "solid" | "ghost" }) {
  const cls =
    variant === "solid"
      ? "bg-brand shadow-glow inline-flex items-center gap-2 rounded-2xl px-6 py-4 font-bold transition hover:scale-[1.03]"
      : "inline-flex items-center gap-2 rounded-2xl bg-white/10 px-6 py-4 font-bold ring-1 ring-white/20 transition hover:bg-white/15";
  const external = href.startsWith("#");
  return external ? (
    <a href={href} className={cls}>
      {children}
    </a>
  ) : (
    <Link href={href} className={cls}>
      {children}
    </Link>
  );
}

/** Janela de navegador com o painel do salão (ilustração com dados de exemplo). */
function BrowserMock() {
  const rows: [string, string, string, string, string, string][] = [
    ["08:00", "Mariana Costa", "Corte feminino", "R$ 120,00", "Finalizado", "bg-emerald-100 text-emerald-700"],
    ["09:30", "Camila Duarte", "Coloração", "R$ 260,00", "Em atendimento", "bg-amber-100 text-amber-700"],
    ["10:00", "Fernanda Ribeiro", "Escova modelada", "R$ 80,00", "Confirmado", "bg-violet-100 text-violet-700"],
    ["11:00", "Patrícia Gomes", "Manicure", "R$ 45,00", "Agendado online", "bg-pink-100 text-pink-700"],
  ];
  const menu = ["Agenda", "Clientes", "Serviços", "Equipe", "Produtos", "Financeiro", "Promoções", "Meu plano"];
  return (
    <div className="shadow-soft overflow-hidden rounded-2xl bg-white text-brand-ink ring-1 ring-black/10">
      <div className="flex items-center gap-3 bg-zinc-100 px-4 py-2.5">
        <span className="flex gap-1.5">
          <i className="h-3 w-3 rounded-full bg-red-400" />
          <i className="h-3 w-3 rounded-full bg-amber-400" />
          <i className="h-3 w-3 rounded-full bg-emerald-400" />
        </span>
        <span className="flex-1 truncate rounded-lg bg-white px-3 py-1 text-xs text-zinc-500">🔒 {SITE}/painel</span>
      </div>
      <div className="grid grid-cols-[7.5rem_minmax(0,1fr)] sm:grid-cols-[9rem_minmax(0,1fr)]">
        <div className="bg-night p-3 text-xs font-semibold text-white/80 sm:p-4 sm:text-sm">
          <p className="mb-3 flex items-center gap-2 font-extrabold text-white">
            <img src="/icon-cliente.png" alt="" className="h-6 w-6 rounded-lg" /> Salão Max
          </p>
          {menu.map((m, i) => (
            <p key={m} className={`mb-1 rounded-lg px-2 py-1.5 ${i === 0 ? "bg-white/15 text-white" : ""}`}>
              {m}
            </p>
          ))}
        </div>
        <div className="min-w-0 p-3 sm:p-5">
          <p className="text-xs text-brand-muted">Boa tarde, Carla</p>
          <p className="font-extrabold sm:text-lg">Sexta-feira, 16 de outubro</p>
          <div className="mt-3 grid grid-cols-3 gap-2 text-center">
            {[
              ["8", "Atendimentos"],
              ["R$ 730,00", "Previsto"],
              ["1", "Online"],
            ].map(([v, l]) => (
              <div key={l} className="rounded-xl bg-brand-canvas p-2 ring-1 ring-brand-rose/10">
                <p className="text-sm font-extrabold text-brand-rose sm:text-base">{v}</p>
                <p className="text-[10px] text-brand-muted sm:text-xs">{l}</p>
              </div>
            ))}
          </div>
          <div className="mt-3 space-y-2">
            {rows.map(([h, n, s, v, st, c]) => (
              <div key={h} className="flex items-center gap-2 rounded-xl border border-zinc-100 p-2 text-xs sm:gap-3 sm:text-sm">
                <span className="w-10 font-extrabold sm:w-12">{h}</span>
                <span className="min-w-0 flex-1">
                  <b className="block truncate">{n}</b>
                  <span className="block truncate text-brand-muted">{s}</span>
                </span>
                <span className={`hidden rounded-full px-2 py-0.5 text-[10px] font-bold sm:inline sm:text-xs ${c}`}>{st}</span>
                <span className="font-extrabold text-brand-rose">{v}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/** Cartão do painel do representante (ilustração com dados de exemplo). */
function RepCardMock({ code }: { code?: string }) {
  return (
    <div className="float-slow shadow-soft mx-auto w-full max-w-sm rounded-[2rem] bg-white p-6 text-brand-ink">
      <p className="text-xs font-extrabold uppercase tracking-widest text-brand-rose">Seu link de indicação</p>
      <div className="mt-2 flex items-center gap-2 rounded-2xl bg-brand-canvas p-3 ring-1 ring-brand-rose/20">
        <span className="min-w-0 flex-1 truncate text-sm font-bold">
          {SITE}/r/{code || "SEUCODIGO"}
        </span>
        <span className="bg-brand rounded-xl px-3 py-1.5 text-xs font-bold text-white">Copiar</span>
      </div>
      <div className="mt-4 grid grid-cols-3 gap-2 text-center">
        {[
          ["12", "pagando"],
          ["5", "em teste"],
          ["1", "vencido"],
        ].map(([v, l]) => (
          <div key={l} className="rounded-2xl bg-zinc-50 p-3">
            <p className="text-xl font-extrabold">{v}</p>
            <p className="text-[11px] text-brand-muted">{l}</p>
          </div>
        ))}
      </div>
      <div className="bg-brand shadow-glow mt-4 rounded-2xl p-4 text-white">
        <p className="text-xs font-semibold text-white/80">Comissão disponível</p>
        <p className="text-3xl font-extrabold">{money(180)}</p>
        <p className="mt-1 text-xs text-white/80">+ {money(45)} em espera</p>
      </div>
      <p className="mt-3 text-center text-[11px] text-brand-muted">Ilustração com dados de exemplo</p>
    </div>
  );
}

/* ───────────── públicos ───────────── */

const FEATURES = [
  { icon: "calendar", title: "Agenda por profissional", text: "Cada cabeleireira, manicure ou barbeiro tem a sua agenda, sem encaixes duplicados. Encaixe manual quando precisar." },
  { icon: "phone", title: "Agendamento online", text: "Seu link próprio: o cliente marca em 1 minuto, só com nome e WhatsApp, e remarca ou cancela sozinho." },
  { icon: "sparkles", title: "Lembretes e confirmação", text: "Lembrete pelo WhatsApp com o link para o cliente confirmar. Você vê quem vem e quem não confirmou." },
  { icon: "chart", title: "Lucro de verdade", text: "Receita, custos, comissões e despesas, com ajuda para calcular o preço certo de cada serviço." },
  { icon: "box", title: "Produtos e estoque", text: "Venda e uso nos atendimentos, com alerta de estoque baixo." },
  { icon: "palette", title: "Portfólio de fotos", text: "Mostre seus trabalhos por serviço, na página de agendamento do seu salão." },
  { icon: "users", title: "Equipe e clientes", text: "Perfis de dono e funcionário, histórico e anotações de cada cliente. No app, importe o contato da agenda do celular. O financeiro fica só com o dono." },
  { icon: "sparkles", title: "Avisos e histórico", text: "Notificações de agendamentos no celular e no site, com filtro por dia e mês e limpeza automática das antigas." },
  { icon: "clock", title: "Seu horário, do seu jeito", text: "Horário de cada dia da semana, pausas como o almoço e fuso do seu estado." },
  { icon: "shield", title: "Dados protegidos", text: "Os dados de cada salão ficam separados, com conexão criptografada. Exclua sua conta quando quiser." },
];

const BEFORE_AFTER = [
  ["Agenda no caderno e horários batendo", "Agenda por profissional, com status coloridos e sem encaixes duplicados."],
  ["WhatsApp lotado só para marcar horário", "O cliente agenda sozinho pelo seu link, a qualquer hora, e cai direto na agenda."],
  ["Não sabe quanto o salão realmente lucra", "Financeiro com receita, custos, comissões e o preço certo de cada serviço."],
];

const DAY = [
  { icon: "calendar", when: "Ao abrir o salão", title: "A agenda do dia na tela", text: "Veja quem vem, com qual profissional, quanto tempo leva e o valor previsto do dia." },
  { icon: "phone", when: "Durante o dia", title: "Cliente agenda sozinho", text: "O horário cai na agenda na hora e o sino do app avisa. Você confirma com um toque." },
  { icon: "scissors", when: "No atendimento", title: "Iniciar e finalizar", text: "Toque para iniciar e finalizar. A comissão de cada profissional é calculada sozinha." },
  { icon: "chart", when: "No fim do mês", title: "Lucro à vista", text: "Receita, custos, comissões e lucro. Descubra quais serviços mais faturam e quais dão prejuízo." },
];

const SALON_STEPS = [
  ["Crie sua conta", "Nome do salão, seu e-mail e uma senha. O teste grátis começa na hora, sem cartão."],
  ["Cadastre serviços e equipe", "Preços, duração e quem faz cada serviço. Fotos dos seus trabalhos são opcionais."],
  ["Defina seus horários", "Horário de cada dia da semana, pausas como o almoço e folgas."],
  ["Compartilhe seu link", `${SITE}/s/nome-do-seu-salao no Instagram, no WhatsApp e no Google.`],
  ["Receba e atenda", "Os agendamentos caem na agenda. É só confirmar, atender e acompanhar o lucro."],
];

function Salon({ signup, goTo }: { signup: string; goTo: (a: Audience) => void }) {
  const [mode, setMode] = useState<"web" | "app">("web");
  return (
    <>
      <section id="problema" className="mx-auto max-w-6xl scroll-mt-24 px-4 py-20">
        <Head kicker="Seu dia a dia muda" title="Menos tempo no WhatsApp, mais tempo atendendo" />
        <div className="mt-12 space-y-4">
          {BEFORE_AFTER.map(([before, after], i) => (
            <Reveal key={before} delay={i * 80}>
              <div className="grid items-stretch gap-3 md:grid-cols-[1fr_auto_1fr]">
                <div className="rounded-3xl bg-zinc-100 p-5 text-zinc-600">
                  <p className="text-xs font-extrabold uppercase tracking-widest text-zinc-400">Antes</p>
                  <p className="mt-1 font-bold">{before}</p>
                </div>
                <div className="bg-brand mx-auto flex h-10 w-10 rotate-90 items-center justify-center self-center rounded-full text-white md:rotate-0">
                  <Icon name="arrow" className="h-5 w-5" />
                </div>
                <div className="shadow-soft rounded-3xl bg-white p-5 ring-2 ring-brand-rose/20">
                  <p className="text-xs font-extrabold uppercase tracking-widest text-brand-rose">Com o Salão Max</p>
                  <p className="mt-1 font-bold">{after}</p>
                </div>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      <section id="funcoes" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Tudo que seu salão precisa" title="Um sistema completo, feito para beleza" />
        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f, i) => (
            <Reveal key={f.title} delay={(i % 3) * 80}>
              <div className="shadow-soft h-full rounded-3xl bg-white p-6 transition hover:-translate-y-1">
                <div className="bg-brand shadow-glow flex h-12 w-12 items-center justify-center rounded-2xl text-white">
                  <Icon name={f.icon} className="h-6 w-6" />
                </div>
                <h3 className="mt-4 text-lg font-extrabold">{f.title}</h3>
                <p className="mt-1 text-brand-muted">{f.text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      <section id="versoes" className="bg-night relative scroll-mt-24 overflow-hidden px-4 py-20 text-white">
        <div className="pointer-events-none absolute -right-32 top-0 h-96 w-96 rounded-full bg-brand-rose/40 blur-3xl" />
        <div className="relative mx-auto max-w-6xl">
          <div className="mx-auto max-w-2xl text-center">
            <p className="text-sm font-extrabold uppercase tracking-widest text-brand-pink">Duas formas de usar</p>
            <h2 className="mt-2 text-3xl font-extrabold tracking-tight sm:text-4xl">No computador ou no celular. Os dados são os mesmos.</h2>
            <p className="mt-3 text-white/70">O que você faz de um lado aparece do outro na hora.</p>
          </div>
          <div role="tablist" aria-label="Versão" className="mx-auto mt-8 flex w-fit rounded-2xl bg-white/10 p-1 ring-1 ring-white/15">
            {(
              [
                ["web", "Versão web"],
                ["app", "App no celular"],
              ] as const
            ).map(([id, label]) => (
              <button
                key={id}
                role="tab"
                aria-selected={mode === id}
                onClick={() => setMode(id)}
                className={`rounded-xl px-5 py-2.5 text-sm font-bold transition ${mode === id ? "bg-brand shadow-glow" : "text-white/70 hover:text-white"}`}
              >
                {label}
              </button>
            ))}
          </div>

          <div className="mt-10 grid items-center gap-10 lg:grid-cols-2">
            {mode === "web" ? (
              <>
                <div className="order-2 lg:order-1">
                  <h3 className="text-2xl font-extrabold">Versão web: abre no navegador</h3>
                  <ul className="mt-5 space-y-3 text-white/85">
                    {[
                      "Nada para instalar: funciona no computador, tablet ou celular.",
                      "Ótima para a recepção: agenda grande na tela e cadastro completo.",
                      "Serviços, equipe, produtos, financeiro, promoções e portfólio de fotos.",
                      "Assinatura pelo site com Pix, boleto ou cartão.",
                    ].map((t) => (
                      <li key={t} className="flex gap-3">
                        <Icon name="check" className="mt-1 h-5 w-5 shrink-0 text-emerald-300" /> {t}
                      </li>
                    ))}
                  </ul>
                  <p className="mt-6 inline-flex items-baseline gap-2 rounded-2xl bg-white/10 px-5 py-3 ring-1 ring-white/15">
                    <span className="text-sm text-white/70">Assinando pelo site</span>
                    <b className="text-2xl">R$ {PRICE_SITE}</b>
                    <span className="text-sm text-white/70">/mês</span>
                  </p>
                </div>
                <div className="order-1 lg:order-2">
                  <BrowserMock />
                </div>
              </>
            ) : (
              <>
                <div className="order-2 lg:order-1">
                  <h3 className="text-2xl font-extrabold">App Salão Max Gestão: o salão no seu bolso</h3>
                  <ul className="mt-5 space-y-3 text-white/85">
                    {[
                      "Agenda do dia no celular, com aviso de novos agendamentos.",
                      "Entre uma vez e fique conectado; o app atualiza sozinho.",
                      "Encaixe, confirme, inicie e finalize atendimentos em um toque.",
                      "Assinatura pela Google Play, com o cartão que você já tem na loja.",
                    ].map((t) => (
                      <li key={t} className="flex gap-3">
                        <Icon name="check" className="mt-1 h-5 w-5 shrink-0 text-emerald-300" /> {t}
                      </li>
                    ))}
                  </ul>
                  <div className="mt-6 flex flex-wrap items-center gap-3">
                    <p className="inline-flex items-baseline gap-2 rounded-2xl bg-white/10 px-5 py-3 ring-1 ring-white/15">
                      <span className="text-sm text-white/70">Assinando pela Play</span>
                      <b className="text-2xl">R$ {PRICE_PLAY}</b>
                      <span className="text-sm text-white/70">/mês</span>
                    </p>
                    <Link href="/baixar" className="rounded-2xl bg-white/10 px-5 py-3 font-bold ring-1 ring-white/20 hover:bg-white/15">
                      {PLAY_LIVE ? "Baixar na Google Play" : "Baixar o app agora"}
                    </Link>
                  </div>
                  {!PLAY_LIVE && <p className="mt-3 text-sm text-white/60">Em breve também na Google Play.</p>}
                </div>
                <div className="order-1 mx-auto flex w-full max-w-sm gap-4 lg:order-2">
                  <PhoneFrame src="/screens/gestao-agenda.webp" top="#2F1762" alt="Agenda do dia no app" className="float-slow w-1/2" />
                  <PhoneFrame src="/screens/gestao-novo.jpg" top="#150B2D" alt="Novo agendamento no app" className="float-slow-2 w-1/2 translate-y-10" />
                </div>
              </>
            )}
          </div>
        </div>
      </section>

      <section id="precos" className="mx-auto max-w-6xl scroll-mt-24 px-4 py-20">
        <Head
          kicker="Preço"
          title="Um plano completo. Pelo site é mais barato."
          text="É o mesmo sistema e o mesmo plano. A diferença de preço é só a taxa que a loja do Google cobra."
        />
        <div className="mx-auto mt-12 grid max-w-4xl gap-5 md:grid-cols-2">
          <Reveal>
            <div className="bg-brand shadow-glow relative h-full rounded-[2rem] p-7 text-white">
              <span className="absolute -top-3 right-6 rounded-full bg-amber-300 px-3 py-1 text-xs font-extrabold text-brand-ink">Mais barato</span>
              <p className="text-sm font-extrabold uppercase tracking-widest text-white/80">Pelo site</p>
              <p className="mt-2 text-5xl font-extrabold">
                R$ {PRICE_SITE}
                <span className="text-lg font-semibold text-white/80"> /mês</span>
              </p>
              <ul className="mt-5 space-y-2 text-white/90">
                {["Versão web e app, tudo liberado", "Pague com Pix, boleto ou cartão", "Cartão renova sozinho", "Cancele quando quiser"].map((t) => (
                  <li key={t} className="flex gap-2">
                    <Icon name="check" className="mt-0.5 h-5 w-5 shrink-0" /> {t}
                  </li>
                ))}
              </ul>
              <Link href={signup} className="mt-6 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-white px-5 py-3.5 font-extrabold text-brand-rose">
                Testar grátis <Icon name="arrow" />
              </Link>
            </div>
          </Reveal>
          <Reveal delay={100}>
            <div className="shadow-soft h-full rounded-[2rem] bg-white p-7">
              <p className="text-sm font-extrabold uppercase tracking-widest text-brand-muted">Pela Google Play</p>
              <p className="mt-2 text-5xl font-extrabold">
                R$ {PRICE_PLAY}
                <span className="text-lg font-semibold text-brand-muted"> /mês</span>
              </p>
              <ul className="mt-5 space-y-2 text-brand-muted">
                {["O mesmo plano completo", "Assinatura dentro da loja do Google", "Cobrança no cartão da sua conta Google", "Cancele quando quiser, pela Play"].map((t) => (
                  <li key={t} className="flex gap-2">
                    <Icon name="check" className="mt-0.5 h-5 w-5 shrink-0 text-brand-rose" /> {t}
                  </li>
                ))}
              </ul>
              <p className="mt-6 rounded-2xl bg-brand-canvas p-4 text-sm text-brand-muted ring-1 ring-brand-rose/15">
                <b className="text-brand-ink">Por que R$ 9,00 a mais?</b> A Google Play fica com cerca de 15% de cada assinatura feita pela loja. Pelo site essa taxa não existe, então o mesmo plano sai mais barato.
              </p>
            </div>
          </Reveal>
        </div>

        <div className="mx-auto mt-10 grid max-w-4xl gap-4 sm:grid-cols-3">
          {[
            ["Cartão", "Fica salvo e renova sozinho, sem esquecer de pagar."],
            ["Pix", "O aviso de pagamento chega por e-mail todo mês."],
            ["Boleto", "Chega por e-mail e compensa em 1 a 3 dias."],
          ].map(([t, d]) => (
            <div key={t} className="shadow-soft rounded-2xl bg-white p-5 text-center">
              <p className="text-lg font-extrabold text-brand-rose">{t}</p>
              <p className="mt-1 text-sm text-brand-muted">{d}</p>
            </div>
          ))}
        </div>

        <div className="mx-auto mt-6 grid max-w-4xl gap-4 sm:grid-cols-2">
          <div className="rounded-2xl bg-emerald-50 p-5 text-emerald-900 ring-1 ring-emerald-200">
            <p className="font-extrabold">Teste grátis de {TRIAL_DAYS} dias, sem cartão</p>
            <p className="mt-1 text-sm">No teste há limites de cadastro para você conhecer. No plano pago, equipe, serviços e clientes sem limite.</p>
          </div>
          <div className="rounded-2xl bg-violet-50 p-5 text-violet-900 ring-1 ring-violet-200">
            <p className="font-extrabold">Cancele quando quiser</p>
            <p className="mt-1 text-sm">No site: Meu plano → Cancelar assinatura. Na Play: pelo app, em Ajustes. Você usa até o fim do período já pago.</p>
          </div>
        </div>
      </section>

      <section id="dia" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Como o cabeleireiro usa" title="Do abrir ao fechar o salão" />
        <div className="relative mx-auto mt-12 max-w-3xl">
          <div className="absolute bottom-4 left-6 top-4 w-1 rounded-full bg-gradient-to-b from-brand-pink via-brand-rose to-brand-violet" aria-hidden />
          <ol className="space-y-8">
            {DAY.map((d, i) => (
              <Reveal key={d.title} delay={i * 80}>
                <li className="relative flex gap-5">
                  <span className="bg-brand shadow-glow z-10 flex h-12 w-12 shrink-0 items-center justify-center rounded-full text-white">
                    <Icon name={d.icon} className="h-6 w-6" />
                  </span>
                  <div className="shadow-soft flex-1 rounded-3xl bg-white p-5">
                    <p className="text-xs font-extrabold uppercase tracking-widest text-brand-rose">{d.when}</p>
                    <h3 className="mt-1 text-lg font-extrabold">{d.title}</h3>
                    <p className="text-brand-muted">{d.text}</p>
                  </div>
                </li>
              </Reveal>
            ))}
          </ol>
        </div>
      </section>

      <section id="passos" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <div className="grid items-center gap-10 rounded-[2.5rem] bg-white p-8 shadow-soft lg:grid-cols-2 lg:p-14">
          <div>
            <h2 className="text-3xl font-extrabold tracking-tight">Comece hoje, em 5 passos</h2>
            <ol className="mt-8 space-y-5">
              {SALON_STEPS.map(([title, text], i) => (
                <li key={title} className="flex gap-4">
                  <span className="bg-brand flex h-10 w-10 shrink-0 items-center justify-center rounded-full font-extrabold text-white">{i + 1}</span>
                  <div>
                    <p className="font-extrabold">{title}</p>
                    <p className="text-brand-muted">{text}</p>
                  </div>
                </li>
              ))}
            </ol>
            <Link href={signup} className="bg-brand shadow-glow mt-8 inline-flex items-center gap-2 rounded-2xl px-6 py-4 font-bold text-white">
              Criar meu salão <Icon name="arrow" />
            </Link>
          </div>
          <div className="mx-auto flex w-full max-w-sm gap-4">
            <PhoneFrame src="/screens/gestao-cadastros.jpg" top="#291556" alt="Cadastros do salão" className="w-1/2 translate-y-8" />
            <PhoneFrame src="/screens/gestao-precificacao.jpg" top="#2C165C" alt="Preço certo de cada serviço" className="w-1/2" />
          </div>
        </div>
      </section>

      <section id="duvidas" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Dúvidas frequentes" title="Perguntas que todo dono de salão faz" />
        <Faq
          items={[
            ["Preciso instalar alguma coisa?", "Não. O Salão Max funciona direto no navegador, no computador ou no celular. O app é opcional."],
            ["Posso testar antes de pagar?", `Sim. O teste grátis dura ${TRIAL_DAYS} dias e não pede cartão.`],
            ["Meu cliente precisa baixar app ou criar conta?", "Não. Ele abre o seu link, escolhe o serviço e o horário e informa só nome e WhatsApp."],
            ["Assinei pelo site e quero usar o app. Funciona?", "Funciona. O plano é do salão, então vale no site e no app, com o mesmo e-mail e senha."],
            ["Como eu cancelo?", "Pelo site, em Meu plano → Cancelar assinatura. Pela Play, no app, em Ajustes. Você continua com o plano até o fim do período já pago."],
            ["Meus dados e os dos meus clientes estão seguros?", "Os dados de cada salão ficam separados, com conexão criptografada, e você pode excluir a conta quando quiser."],
          ]}
        />
      </section>

      <section className="px-4 pb-6">
        <div className="bg-brand relative mx-auto max-w-6xl overflow-hidden rounded-[2.5rem] px-8 py-14 text-center text-white">
          <div className="pointer-events-none absolute -left-10 -top-10 h-60 w-60 rounded-full bg-white/20 blur-2xl" />
          <h2 className="relative text-3xl font-extrabold tracking-tight sm:text-4xl">Seu salão merece uma agenda assim</h2>
          <p className="relative mx-auto mt-3 max-w-xl text-white/85">Teste {TRIAL_DAYS} dias grátis, sem cartão. Crie o salão em poucos minutos.</p>
          <div className="relative mt-8 flex flex-wrap justify-center gap-3">
            <Link href={signup} className="inline-flex items-center gap-2 rounded-2xl bg-white px-6 py-4 font-extrabold text-brand-rose">
              Testar grátis <Icon name="arrow" />
            </Link>
            <button onClick={() => goTo("cliente")} className="rounded-2xl bg-white/15 px-6 py-4 font-bold ring-1 ring-white/30 hover:bg-white/20">
              Ver como o cliente agenda
            </button>
          </div>
        </div>
      </section>
    </>
  );
}

const CLIENT_STEPS = [
  { title: "Encontre seu salão", text: "Pelo nome ou pelo link que o salão enviou.", src: "/screens/cliente-home.jpg", top: "#EC418B" },
  { title: "Escolha o serviço e quem atende", text: "Corte, escova, coloração, manicure e mais, com preço e duração.", src: "/screens/cliente-salao.jpg", top: "#E5267A" },
  { title: "Toque num horário livre", text: "Os horários são atualizados em tempo real. Sem ligação e sem esperar resposta.", src: "/screens/cliente-horarios.webp", top: "#E5267A" },
  { title: "Informe nome e WhatsApp", text: "Só isso. Sem cadastro e sem senha. O horário fica confirmado.", src: "/screens/cliente-confirmado.webp", top: "#F0468A" },
  { title: "Veja seus horários quando quiser", text: "Próximos agendamentos e histórico, tudo à mão.", src: "/screens/cliente-meus-horarios.jpg", top: "#DD3B96" },
];

function Client({ goTo }: { goTo: (a: Audience) => void }) {
  const [step, setStep] = useState(0);
  const [auto, setAuto] = useState(true);
  useEffect(() => {
    if (!auto) return;
    const t = setInterval(() => setStep((s) => (s + 1) % CLIENT_STEPS.length), 3800);
    return () => clearInterval(t);
  }, [auto]);
  const pick = (i: number) => {
    setAuto(false);
    setStep(i);
  };
  return (
    <>
      <section id="como" className="mx-auto max-w-6xl scroll-mt-24 px-4 py-20">
        <Head kicker="Passo a passo" title="Agendar leva menos de 1 minuto" text="Toque em um passo para ver a tela." />
        <div className="mt-12 grid items-center gap-10 lg:grid-cols-[1fr_auto]">
          <ol className="space-y-3">
            {CLIENT_STEPS.map((s, i) => (
              <li key={s.title}>
                <button
                  onClick={() => pick(i)}
                  className={`flex w-full gap-4 rounded-3xl p-4 text-left transition ${step === i ? "shadow-soft bg-white ring-2 ring-brand-rose/40" : "hover:bg-white/60"}`}
                >
                  <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full font-extrabold ${step === i ? "bg-brand text-white" : "bg-zinc-200 text-zinc-500"}`}>
                    {i + 1}
                  </span>
                  <span>
                    <b className="block">{s.title}</b>
                    <span className="text-brand-muted">{s.text}</span>
                  </span>
                </button>
              </li>
            ))}
          </ol>
          <div className="relative mx-auto w-64 sm:w-72">
            <div className="pointer-events-none absolute -inset-8 rounded-full bg-brand-rose/20 blur-3xl" />
            {CLIENT_STEPS.map((s, i) => (
              <div key={s.src} className={`transition-opacity duration-500 ${i === step ? "relative opacity-100" : "pointer-events-none absolute inset-0 opacity-0"}`}>
                <PhoneFrame src={s.src} top={s.top} alt={s.title} eager={i === 0} />
              </div>
            ))}
            <div className="mt-4 flex justify-center gap-2">
              {CLIENT_STEPS.map((s, i) => (
                <button key={s.title} aria-label={`Passo ${i + 1}`} onClick={() => pick(i)} className={`h-2.5 rounded-full transition-all ${step === i ? "bg-brand w-8" : "w-2.5 bg-zinc-300"}`} />
              ))}
            </div>
          </div>
        </div>
      </section>

      <section id="vantagens" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Por que é melhor" title="Feito para a sua vida correr" />
        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {[
            ["user", "Sem cadastro e sem senha", "Informe só nome e WhatsApp. Nada de criar conta."],
            ["clock", "Horários em tempo real", "Você só vê o que está livre de verdade."],
            ["check", "Comprovante na hora", "Data, hora, profissional e valor, bem organizados."],
            ["sparkles", "Lembrete do horário", "O salão avisa e você confirma com um toque."],
            ["shuffle", "Remarque ou cancele", "Pelo link do seu agendamento, quando precisar."],
            ["shield", "Privacidade em primeiro lugar", "Seus dados vão só para o salão escolhido. Sem anúncios."],
          ].map(([icon, t, d], i) => (
            <Reveal key={t} delay={(i % 3) * 80}>
              <div className="shadow-soft h-full rounded-3xl bg-white p-6">
                <div className="bg-brand shadow-glow flex h-12 w-12 items-center justify-center rounded-2xl text-white">
                  <Icon name={icon} className="h-6 w-6" />
                </div>
                <h3 className="mt-4 text-lg font-extrabold">{t}</h3>
                <p className="mt-1 text-brand-muted">{d}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      <section id="onde" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Onde eu agendo?" title="Do jeito que for mais fácil para você" />
        <div className="mx-auto mt-12 grid max-w-4xl gap-5 md:grid-cols-2">
          <div className="bg-brand shadow-glow rounded-[2rem] p-7 text-white">
            <Icon name="phone" className="h-9 w-9" />
            <h3 className="mt-3 text-2xl font-extrabold">Pelo link do seu salão</h3>
            <p className="mt-2 text-white/90">O salão te manda um link. É só abrir no navegador do celular e agendar. Não precisa baixar nada.</p>
            <p className="mt-4 rounded-2xl bg-white/15 px-4 py-3 text-sm font-bold">{SITE}/s/nome-do-salao</p>
          </div>
          <div className="shadow-soft rounded-[2rem] bg-white p-7">
            <Icon name="smile" className="h-9 w-9 text-brand-rose" />
            <h3 className="mt-3 text-2xl font-extrabold">Pelo app Salão Max</h3>
            <p className="mt-2 text-brand-muted">Seus salões ficam salvos e seus horários sempre à mão. Instalação direta no Android{PLAY_LIVE ? " ou pela Google Play" : ", em breve também na Google Play"}.</p>
            <Link href="/baixar" className="bg-brand shadow-glow mt-4 inline-flex items-center gap-2 rounded-2xl px-5 py-3 font-bold text-white">
              Baixar o app <Icon name="arrow" />
            </Link>
          </div>
        </div>
      </section>

      <section id="duvidas" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Dúvidas frequentes" title="Perguntas de quem agenda" />
        <Faq
          items={[
            ["Preciso pagar para usar?", "Não. Agendar pelo link ou pelo app é grátis para você."],
            ["Preciso criar uma conta?", "Não. Você informa só seu nome e seu WhatsApp, e usa os mesmos dados para ver seus horários depois."],
            ["E se eu não puder ir?", "Você pode remarcar ou cancelar pelo link do seu agendamento. Veja a regra do seu salão."],
            ["Meus dados estão seguros?", "Eles vão só para o salão que você escolheu. Não há anúncios nem rastreamento."],
          ]}
        />
      </section>

      <section className="px-4 pb-6">
        <div className="bg-brand relative mx-auto max-w-6xl overflow-hidden rounded-[2.5rem] px-8 py-14 text-center text-white">
          <div className="pointer-events-none absolute -left-10 -top-10 h-60 w-60 rounded-full bg-white/20 blur-2xl" />
          <h2 className="relative text-3xl font-extrabold tracking-tight sm:text-4xl">Peça o link ao seu salão</h2>
          <p className="relative mx-auto mt-3 max-w-xl text-white/85">Seu salão ainda não usa o Salão Max? Mostre esta página para ele.</p>
          <div className="relative mt-8 flex flex-wrap justify-center gap-3">
            <button onClick={() => goTo("salao")} className="inline-flex items-center gap-2 rounded-2xl bg-white px-6 py-4 font-extrabold text-brand-rose">
              Sou dono de salão <Icon name="arrow" />
            </button>
          </div>
        </div>
      </section>
    </>
  );
}

function Rep({ code }: { code?: string }) {
  const [n, setN] = useState(10);
  const [copied, setCopied] = useState(false);
  const link = `https://${SITE}/r/${code || "SEUCODIGO"}`;
  const pitch = `Oi! Conhece o Salão Max? É um sistema de agenda e agendamento online para salão: o cliente marca sozinho pelo link, você controla equipe, estoque e lucro. Tem ${TRIAL_DAYS} dias grátis, sem cartão. Veja aqui: ${link}`;
  return (
    <>
      <section id="ganhos" className="mx-auto max-w-6xl scroll-mt-24 px-4 py-20">
        <Head kicker="Simule seus ganhos" title={`Cada salão que paga rende ${money(COMMISSION)} por mês`} text="Arraste e veja quanto você pode receber todo mês enquanto os salões continuarem pagando." />
        <Reveal>
          <div className="shadow-soft mx-auto mt-10 max-w-3xl rounded-[2rem] bg-white p-7 sm:p-10">
            <div className="flex items-end justify-between gap-4">
              <p className="font-bold text-brand-muted">Salões que pagam</p>
              <p className="text-4xl font-extrabold text-brand-rose">{n}</p>
            </div>
            <input
              type="range"
              min={1}
              max={100}
              value={n}
              onChange={(e) => setN(Number(e.target.value))}
              aria-label="Quantidade de salões"
              className="mt-4 h-3 w-full cursor-pointer accent-[#e5267a]"
            />
            <div className="mt-8 grid gap-4 sm:grid-cols-2">
              <div className="bg-brand shadow-glow rounded-3xl p-6 text-white">
                <p className="text-sm font-semibold text-white/80">Por mês</p>
                <p className="text-4xl font-extrabold">{money(n * COMMISSION)}</p>
              </div>
              <div className="bg-night rounded-3xl p-6 text-white">
                <p className="text-sm font-semibold text-white/70">Em 12 meses</p>
                <p className="text-4xl font-extrabold">{money(n * COMMISSION * 12)}</p>
              </div>
            </div>
            <p className="mt-4 text-center text-xs text-brand-muted">Simulação. O valor real depende de quantos salões assinam e continuam pagando.</p>
          </div>
        </Reveal>
      </section>

      <section id="funciona" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Como funciona" title="Do cadastro à comissão em 4 passos" />
        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {[
            ["Cadastre-se grátis", `Em ${SITE}/representantes, com nome, e-mail e senha. A chave Pix pode vir depois.`],
            ["Receba seu link", `Você ganha um código e um link só seu: ${SITE}/r/SEUCODIGO.`],
            ["Mande para os salões", "WhatsApp, Instagram, conversa pessoal. Mostre esta apresentação junto."],
            ["O salão assina, você ganha", `O salão se cadastra pelo seu link, testa e assina. Cada mensalidade paga rende ${money(COMMISSION)}.`],
          ].map(([t, d], i) => (
            <Reveal key={t} delay={i * 80}>
              <div className="shadow-soft h-full rounded-3xl bg-white p-6">
                <span className="bg-brand shadow-glow flex h-11 w-11 items-center justify-center rounded-full text-lg font-extrabold text-white">{i + 1}</span>
                <h3 className="mt-4 text-lg font-extrabold">{t}</h3>
                <p className="mt-1 text-brand-muted">{d}</p>
              </div>
            </Reveal>
          ))}
        </div>
        <p className="mx-auto mt-6 max-w-2xl rounded-2xl bg-amber-50 p-4 text-center text-sm text-amber-900 ring-1 ring-amber-200">
          <b>Importante:</b> a indicação vale quando o salão se cadastra pelo seu link. Ele guarda o seu código no aparelho ao abrir o link, por isso use sempre o seu.
        </p>
      </section>

      <section id="painel" className="bg-night relative scroll-mt-24 overflow-hidden px-4 py-20 text-white">
        <div className="pointer-events-none absolute -left-32 top-0 h-96 w-96 rounded-full bg-brand-violet/40 blur-3xl" />
        <div className="relative mx-auto grid max-w-6xl items-center gap-10 lg:grid-cols-2">
          <div>
            <p className="text-sm font-extrabold uppercase tracking-widest text-brand-pink">Seu painel de representante</p>
            <h2 className="mt-2 text-3xl font-extrabold tracking-tight sm:text-4xl">Tudo no navegador, em {SITE}/representante</h2>
            <ul className="mt-6 space-y-3 text-white/85">
              {[
                "Seu link pronto para copiar e compartilhar.",
                "Os salões que você indicou: pagando, em teste ou vencidos.",
                "Suas comissões: em espera, disponível, paga ou estornada.",
                "Sua chave Pix, para receber.",
              ].map((t) => (
                <li key={t} className="flex gap-3">
                  <Icon name="check" className="mt-1 h-5 w-5 shrink-0 text-emerald-300" /> {t}
                </li>
              ))}
            </ul>
            <div className="mt-8 flex flex-wrap gap-3">
              <CtaButton href="/representantes">
                Criar meu link <Icon name="arrow" />
              </CtaButton>
              <CtaButton href="/login" variant="ghost">
                Já sou representante
              </CtaButton>
            </div>
          </div>
          <RepCardMock code={code} />
        </div>
      </section>

      <section id="regras" className="mx-auto max-w-6xl scroll-mt-24 px-4 py-20">
        <Head kicker="Regras da comissão" title="Claras e justas" />
        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {[
            ["check", `${money(COMMISSION)} por mensalidade paga`, "Vale para quem assina pelo site ou pela Google Play, todo mês em que o pagamento for confirmado."],
            ["clock", "7 dias em espera", "Depois do pagamento, a comissão fica 7 dias em espera (prazo de arrependimento) e então fica disponível."],
            ["hand", "Pagamento por Pix", "A plataforma faz o Pix para a sua chave e marca como pago. Você acompanha tudo no painel."],
            ["shuffle", "Se o salão cancelar", "Os próximos meses deixam de contar. O que já foi pago continua sendo seu."],
            ["shield", "Se houver estorno", "Em caso de estorno ou contestação, aquela comissão é descontada."],
            ["users", "Sem limite de salões", "Indique quantos quiser. Quanto mais salões pagando, maior a renda recorrente."],
          ].map(([icon, t, d], i) => (
            <Reveal key={t} delay={(i % 3) * 80}>
              <div className="shadow-soft h-full rounded-3xl bg-white p-6">
                <div className="bg-brand shadow-glow flex h-12 w-12 items-center justify-center rounded-2xl text-white">
                  <Icon name={icon} className="h-6 w-6" />
                </div>
                <h3 className="mt-4 text-lg font-extrabold">{t}</h3>
                <p className="mt-1 text-brand-muted">{d}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      <section id="vender" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Como vender" title="Argumentos que convencem" />
        <div className="mt-12 grid gap-5 lg:grid-cols-2">
          <div className="shadow-soft rounded-3xl bg-white p-7">
            <h3 className="text-lg font-extrabold">Diga isto ao dono do salão</h3>
            <ul className="mt-4 space-y-3 text-brand-muted">
              {[
                "O cliente agenda sozinho, sem ficar mandando mensagem no WhatsApp.",
                "A agenda de cada profissional, sem horários batendo.",
                "Financeiro: lucro, comissões e o preço certo de cada serviço.",
                `Teste de ${TRIAL_DAYS} dias grátis, sem cartão.`,
                `Pelo site são R$ ${PRICE_SITE} por mês. Pela Google Play são R$ ${PRICE_PLAY}, por causa da taxa da loja.`,
                "Cancela quando quiser.",
              ].map((t) => (
                <li key={t} className="flex gap-3">
                  <Icon name="check" className="mt-1 h-5 w-5 shrink-0 text-brand-rose" /> {t}
                </li>
              ))}
            </ul>
          </div>
          <div className="bg-night rounded-3xl p-7 text-white">
            <h3 className="text-lg font-extrabold">Mensagem pronta para o WhatsApp</h3>
            <p className="mt-4 rounded-2xl bg-white/10 p-4 text-sm leading-relaxed text-white/90 ring-1 ring-white/15">{pitch}</p>
            <div className="mt-5 flex flex-wrap gap-3">
              <button
                onClick={async () => {
                  setCopied(await copyText(pitch));
                  setTimeout(() => setCopied(false), 2200);
                }}
                className="bg-brand shadow-glow rounded-2xl px-5 py-3 font-bold"
              >
                {copied ? "Copiado!" : "Copiar mensagem"}
              </button>
              <a href={`https://wa.me/?text=${encodeURIComponent(pitch)}`} target="_blank" rel="noreferrer" className="rounded-2xl bg-white/10 px-5 py-3 font-bold ring-1 ring-white/20 hover:bg-white/15">
                Enviar pelo WhatsApp
              </a>
            </div>
            {!code && <p className="mt-3 text-xs text-white/60">Troque SEUCODIGO pelo código que você receber no cadastro.</p>}
          </div>
        </div>
      </section>

      <section id="duvidas" className="mx-auto max-w-6xl scroll-mt-24 px-4 pb-20">
        <Head kicker="Dúvidas frequentes" title="Perguntas de quem quer indicar" />
        <Faq
          items={[
            ["Preciso pagar para ser representante?", "Não. O cadastro é grátis e você recebe o link na hora."],
            ["Quanto o salão paga?", `R$ ${PRICE_SITE} por mês pelo site (Pix, boleto ou cartão) e R$ ${PRICE_PLAY} pela Google Play. Você ganha ${money(COMMISSION)} nos dois casos.`],
            ["Quando eu recebo?", "A comissão fica 7 dias em espera depois do pagamento. Depois fica disponível, e a plataforma faz o Pix para a sua chave."],
            ["Onde acompanho meus ganhos?", `No seu painel, em ${SITE}/representante: salões indicados, comissões e chave Pix.`],
            ["E se o salão cancelar?", "Os próximos meses deixam de gerar comissão. O que já foi pago continua sendo seu."],
          ]}
        />
      </section>

      <section className="px-4 pb-6">
        <div className="bg-brand relative mx-auto max-w-6xl overflow-hidden rounded-[2.5rem] px-8 py-14 text-center text-white">
          <div className="pointer-events-none absolute -left-10 -top-10 h-60 w-60 rounded-full bg-white/20 blur-2xl" />
          <h2 className="relative text-3xl font-extrabold tracking-tight sm:text-4xl">Comece a indicar hoje</h2>
          <p className="relative mx-auto mt-3 max-w-xl text-white/85">Crie seu link em 1 minuto e receba {money(COMMISSION)} por mês por cada salão que assinar.</p>
          <div className="relative mt-8 flex flex-wrap justify-center gap-3">
            <Link href="/representantes" className="inline-flex items-center gap-2 rounded-2xl bg-white px-6 py-4 font-extrabold text-brand-rose">
              Criar meu link <Icon name="arrow" />
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}

/* ───────────── página ───────────── */

export function Presentation({ code, audiences = ["salao", "cliente", "representante"] }: { code?: string; audiences?: Audience[] }) {
  const tabs = TABS.filter((t) => audiences.includes(t.id));
  const [aud, setAud] = useState<Audience>(tabs[0].id);
  const [shared, setShared] = useState(false);
  const signup = code ? `/cadastro?ref=${code}` : "/cadastro";

  useEffect(() => {
    const h = window.location.hash.replace("#", "") as Audience;
    if (audiences.includes(h)) setAud(h);
    if (code) {
      try {
        localStorage.setItem(REF_KEY, code);
      } catch {
        // o código também vai na URL do cadastro
      }
    }
    // roda só na abertura da página
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const goTo = useCallback((a: Audience) => {
    setAud(a);
    history.replaceState(null, "", `#${a}`);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, []);

  const heroes: Record<Audience, { badge: string; title: ReactNode; text: string; primary: [string, string]; secondary: [string, string]; visual: ReactNode }> = {
    salao: {
      badge: "Para salões, barbearias e esmalterias",
      title: (
        <>
          Seu salão cheio, organizado e <span className="text-brand">lucrando</span>.
        </>
      ),
      text: "Agenda, agendamento online, clientes, estoque e financeiro em um só lugar. Use no computador ou no celular.",
      primary: [`Testar ${TRIAL_DAYS} dias grátis`, signup],
      secondary: ["Ver como funciona", "#funcoes"],
      visual: <PhonePair a={{ src: "/screens/gestao-agenda.webp", top: "#2F1762", alt: "Agenda do dia no app" }} b={{ src: "/screens/gestao-financeiro.webp", top: "#291557", alt: "Financeiro do salão" }} />,
    },
    cliente: {
      badge: "Para quem agenda no salão",
      title: (
        <>
          Seu horário no salão em <span className="text-brand">1 minuto</span>.
        </>
      ),
      text: "Sem ligação, sem esperar resposta no WhatsApp e sem criar conta. Escolha o serviço, o profissional e o horário.",
      primary: ["Ver o passo a passo", "#como"],
      secondary: ["Onde eu agendo?", "#onde"],
      visual: <PhonePair a={{ src: "/screens/cliente-home.jpg", top: "#EC418B", alt: "Escolha do salão" }} b={{ src: "/screens/cliente-horarios.webp", top: "#E5267A", alt: "Horários livres" }} />,
    },
    representante: {
      badge: "Programa de representantes",
      title: (
        <>
          Indique salões e ganhe <span className="text-brand">{money(COMMISSION)}</span> por mês por salão.
        </>
      ),
      text: "Receba um link só seu. Cada salão que se cadastrar por ele e pagar a mensalidade gera comissão recorrente para você.",
      primary: ["Criar meu link", "/representantes"],
      secondary: ["Simular meus ganhos", "#ganhos"],
      visual: <RepCardMock code={code} />,
    },
  };
  const hero = heroes[aud];

  return (
    <main className="overflow-hidden">
      <section className="bg-night relative text-white">
        <div className="pointer-events-none absolute -right-32 -top-40 h-[32rem] w-[32rem] rounded-full bg-brand-rose/50 blur-3xl" />
        <div className="pointer-events-none absolute -left-40 bottom-0 h-96 w-96 rounded-full bg-brand-violet/40 blur-3xl" />

        <div className="sticky top-0 z-30 border-b border-white/10 bg-[#140a2e]/85 backdrop-blur">
          <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3">
            <Link href="/" className="flex items-center gap-2 font-extrabold">
              <img src="/icon-cliente.png" alt="" className="h-9 w-9 rounded-xl" />
              <span className="hidden sm:inline">Salão Max</span>
            </Link>
            <div role="tablist" aria-label="Para quem é" className="flex rounded-2xl bg-white/10 p-1 ring-1 ring-white/15">
              {tabs.map((t) => (
                <button
                  key={t.id}
                  role="tab"
                  aria-selected={aud === t.id}
                  onClick={() => goTo(t.id)}
                  className={`flex items-center gap-1.5 rounded-xl px-3 py-2 text-xs font-bold transition sm:px-4 sm:text-sm ${aud === t.id ? "bg-brand shadow-glow" : "text-white/70 hover:text-white"}`}
                >
                  <Icon name={t.icon} className="hidden h-4 w-4 sm:block" />
                  <span className="sm:hidden">{t.short}</span>
                  <span className="hidden sm:inline">{t.label}</span>
                </button>
              ))}
            </div>
            <Link href="/login" className="hidden rounded-xl px-3 py-2 text-sm font-semibold text-white/80 hover:text-white md:block">
              Entrar
            </Link>
          </div>
        </div>

        <div className="relative mx-auto max-w-6xl px-4">
          <div key={aud} className="hero-in grid items-center gap-10 pb-0 pt-10 lg:grid-cols-2 lg:pt-16">
            <div className="pb-6 lg:pb-24">
              {code && (
                <p className="mb-4 inline-flex items-center gap-2 rounded-full bg-amber-300 px-3 py-1 text-sm font-extrabold text-brand-ink">
                  <Icon name="sparkles" className="h-4 w-4" /> Convite de um representante · código {code}
                </p>
              )}
              <span className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-sm font-semibold text-white/90 ring-1 ring-white/15">
                <Icon name="sparkles" className="h-4 w-4 text-amber-300" /> {hero.badge}
              </span>
              <h1 className="mt-5 text-4xl font-extrabold leading-[1.08] tracking-tight sm:text-6xl">{hero.title}</h1>
              <p className="mt-5 max-w-xl text-lg text-white/75">{hero.text}</p>
              <div className="mt-8 flex flex-wrap gap-3">
                <CtaButton href={hero.primary[1]}>
                  {hero.primary[0]} <Icon name="arrow" />
                </CtaButton>
                <CtaButton href={hero.secondary[1]} variant="ghost">
                  {hero.secondary[0]}
                </CtaButton>
              </div>
              {aud === "salao" && (
                <div className="mt-8 flex flex-wrap gap-6 text-sm text-white/70">
                  {["Teste grátis, sem cartão", "Cliente agenda sem cadastro", "Dados protegidos (LGPD)"].map((t) => (
                    <span key={t} className="inline-flex items-center gap-1.5">
                      <Icon name="check" className="h-4 w-4 text-emerald-300" /> {t}
                    </span>
                  ))}
                </div>
              )}
            </div>
            <div className="pb-10 lg:pb-0">{hero.visual}</div>
          </div>
        </div>
      </section>

      <div key={`c-${aud}`} className="hero-in">
        {aud === "salao" && <Salon signup={signup} goTo={goTo} />}
        {aud === "cliente" && <Client goTo={goTo} />}
        {aud === "representante" && <Rep code={code} />}
      </div>

      <footer className="bg-night px-4 py-10 text-white">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-5 text-center">
          <p className="font-extrabold">Gostou? Compartilhe esta apresentação</p>
          <div className="flex flex-wrap justify-center gap-3">
            <button
              onClick={async () => {
                setShared(await copyText(window.location.href.split("#")[0] + `#${aud}`));
                setTimeout(() => setShared(false), 2200);
              }}
              className="rounded-2xl bg-white/10 px-5 py-3 font-bold ring-1 ring-white/20 hover:bg-white/15"
            >
              {shared ? "Link copiado!" : "Copiar link"}
            </button>
            <button
              onClick={() => window.open(`https://wa.me/?text=${encodeURIComponent(`Conheça o Salão Max: ${window.location.href.split("#")[0]}#${aud}`)}`, "_blank")}
              className="bg-brand shadow-glow rounded-2xl px-5 py-3 font-bold"
            >
              Enviar pelo WhatsApp
            </button>
          </div>
          <p className="text-sm text-white/60">
            <Link href="/termos" className="underline">
              Termos
            </Link>{" "}
            ·{" "}
            <Link href="/privacidade" className="underline">
              Privacidade
            </Link>{" "}
            · © Salão Max
          </p>
        </div>
      </footer>
    </main>
  );
}
