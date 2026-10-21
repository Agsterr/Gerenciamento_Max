/* eslint-disable @next/next/no-img-element */
import Link from "next/link";
import { Icon } from "@/components/Icon";
import { PhoneFrame } from "@/components/PhoneFrame";

const FEATURES = [
  { icon: "calendar", title: "Agenda por profissional", text: "Cada cabeleireira, manicure ou barbeiro tem a sua agenda, sem encaixes duplicados. Encaixe manual quando precisar." },
  { icon: "scissors", title: "Cabelo, unhas e mais", text: "Organize os serviços por categoria e escolha quem faz cada um: a cliente só vê horário de quem realmente atende." },
  { icon: "phone", title: "Agendamento online", text: "Seu link próprio: o cliente marca em 1 minuto, só com nome e WhatsApp, e remarca ou cancela sozinho." },
  { icon: "palette", title: "Portfólio de fotos", text: "Mostre seus trabalhos por serviço e categoria, na página de agendamento e no app do cliente." },
  { icon: "sparkles", title: "Lembretes e confirmação", text: "Mande o lembrete pelo WhatsApp com o link para o cliente confirmar. O app dele também avisa sozinho." },
  { icon: "clock", title: "Seu horário, do seu jeito", text: "Horário de cada dia da semana, pausas como o almoço e fuso do seu estado." },
  { icon: "chart", title: "Lucro de verdade", text: "Receita, custos, comissões e despesas, com ajuda para calcular o preço certo de cada serviço." },
  { icon: "box", title: "Produtos e estoque", text: "Venda e uso nos atendimentos, com alerta de estoque baixo." },
  { icon: "users", title: "Equipe e clientes", text: "Perfis de dono e funcionário, histórico e anotações de cada cliente. Entre uma vez e fique conectado." },
];

const STEPS = [
  ["Crie seu salão", "Cadastre serviços, preços e sua equipe em poucos minutos."],
  ["Compartilhe seu link", "Coloque no Instagram, no WhatsApp e no Google."],
  ["Receba agendamentos", "Eles caem direto na sua agenda, prontos para atender."],
];

export default function Home() {
  return (
    <main className="overflow-hidden">
      {/* HERO */}
      <section className="bg-night relative overflow-hidden text-white">
        <div className="pointer-events-none absolute -right-32 -top-40 h-[32rem] w-[32rem] rounded-full bg-brand-rose/50 blur-3xl" />
        <div className="pointer-events-none absolute -left-40 bottom-0 h-96 w-96 rounded-full bg-brand-violet/40 blur-3xl" />
        <div className="relative mx-auto max-w-6xl px-4">
          <header className="flex items-center justify-between py-5">
            <Link href="/" className="flex items-center gap-2 font-extrabold">
              <img src="/icon-cliente.png" alt="" className="h-9 w-9 rounded-xl" />
              Salão Max
            </Link>
            <nav className="flex items-center gap-2 text-sm font-semibold">
              <Link href="/login" className="rounded-xl px-3 py-2 text-white/80 hover:text-white">
                Entrar
              </Link>
              <Link href="/cadastro" className="bg-brand shadow-glow rounded-xl px-4 py-2">
                Criar meu salão
              </Link>
            </nav>
          </header>

          <div className="grid items-center gap-10 pb-0 pt-10 lg:grid-cols-2 lg:pt-16">
            <div className="pb-6 lg:pb-24">
              <span className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-sm font-semibold text-white/90 ring-1 ring-white/15">
                <Icon name="sparkles" className="h-4 w-4 text-amber-300" /> Para salões, barbearias e esmalterias
              </span>
              <h1 className="mt-5 text-4xl font-extrabold leading-[1.08] tracking-tight sm:text-6xl">
                Agenda cheia, organizada e <span className="text-brand">lucrando</span>.
              </h1>
              <p className="mt-5 max-w-xl text-lg text-white/75">
                Agenda, agendamento online, fotos, clientes, estoque e financeiro do seu salão em um só lugar — no celular e no computador.
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Link href="/cadastro" className="bg-brand shadow-glow inline-flex items-center gap-2 rounded-2xl px-6 py-4 font-bold">
                  Testar grátis <Icon name="arrow" />
                </Link>
                <Link href="/login" className="rounded-2xl bg-white/10 px-6 py-4 font-bold ring-1 ring-white/20 hover:bg-white/15">
                  Já tenho conta
                </Link>
              </div>
              <div className="mt-8 flex flex-wrap gap-6 text-sm text-white/70">
                {["Teste grátis, sem cartão", "Cliente agenda sem cadastro", "Dados protegidos (LGPD)"].map((t) => (
                  <span key={t} className="inline-flex items-center gap-1.5">
                    <Icon name="check" className="h-4 w-4 text-emerald-300" /> {t}
                  </span>
                ))}
              </div>
            </div>

            {/* Celular: dois aparelhos inteiros lado a lado. Desktop: inclinados, "saindo" da faixa. */}
            <div className="relative mx-auto w-full max-w-md pb-10 lg:h-[36rem] lg:pb-0">
              <div className="flex items-end justify-center gap-3 lg:block">
                <PhoneFrame
                  src="/screens/gestao-agenda.webp"
                  top="#2A135C"
                  eager
                  alt="App Salão Max Gestão: agenda do dia"
                  className="w-[47%] -rotate-3 lg:absolute lg:-bottom-24 lg:left-0 lg:w-[58%] lg:-rotate-6"
                />
                <PhoneFrame
                  src="/screens/cliente-horarios.webp"
                  top="#E5267A"
                  eager
                  alt="App Salão Max: escolha de horário"
                  className="mb-6 w-[47%] rotate-3 lg:absolute lg:-bottom-10 lg:right-0 lg:mb-0 lg:w-[58%]"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FEATURES */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <p className="text-center text-sm font-extrabold uppercase tracking-widest text-brand-rose">Tudo que seu salão precisa</p>
        <h2 className="mx-auto mt-2 max-w-2xl text-center text-3xl font-extrabold tracking-tight sm:text-4xl">
          Menos tempo no WhatsApp, mais tempo atendendo
        </h2>
        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <div key={f.title} className="shadow-soft rounded-3xl bg-white p-6">
              <div className="bg-brand shadow-glow flex h-12 w-12 items-center justify-center rounded-2xl text-white">
                <Icon name={f.icon} className="h-6 w-6" />
              </div>
              <h3 className="mt-4 text-lg font-extrabold">{f.title}</h3>
              <p className="mt-1 text-brand-muted">{f.text}</p>
            </div>
          ))}
        </div>
      </section>

      {/* HOW */}
      <section className="mx-auto max-w-6xl px-4 pb-20">
        <div className="grid items-center gap-10 rounded-[2.5rem] bg-white p-8 shadow-soft lg:grid-cols-2 lg:p-14">
          <div>
            <h2 className="text-3xl font-extrabold tracking-tight">Comece hoje, em 3 passos</h2>
            <ol className="mt-8 space-y-6">
              {STEPS.map(([title, text], i) => (
                <li key={title} className="flex gap-4">
                  <span className="bg-brand flex h-10 w-10 shrink-0 items-center justify-center rounded-full font-extrabold text-white">{i + 1}</span>
                  <div>
                    <p className="font-extrabold">{title}</p>
                    <p className="text-brand-muted">{text}</p>
                  </div>
                </li>
              ))}
            </ol>
            <Link href="/cadastro" className="bg-brand shadow-glow mt-10 inline-flex items-center gap-2 rounded-2xl px-6 py-4 font-bold text-white">
              Criar meu salão <Icon name="arrow" />
            </Link>
          </div>
          <div className="mx-auto flex w-full max-w-sm gap-4">
            <PhoneFrame src="/screens/gestao-financeiro.webp" top="#271257" alt="Financeiro do salão" className="w-1/2 translate-y-8" />
            <PhoneFrame src="/screens/cliente-confirmado.webp" top="#EE3D85" alt="Agendamento confirmado" className="w-1/2" />
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="px-4 pb-20">
        <div className="bg-brand relative mx-auto max-w-6xl overflow-hidden rounded-[2.5rem] px-8 py-14 text-center text-white">
          <div className="pointer-events-none absolute -left-10 -top-10 h-60 w-60 rounded-full bg-white/20 blur-2xl" />
          <h2 className="relative text-3xl font-extrabold tracking-tight sm:text-4xl">Seu salão merece uma agenda assim</h2>
          <p className="relative mx-auto mt-3 max-w-xl text-white/85">Baixe os apps Salão Max (para clientes) e Salão Max Gestão (para o salão) ou use direto no navegador.</p>
          <div className="relative mt-8 flex flex-wrap justify-center gap-3">
            <Link href="/cadastro" className="rounded-2xl bg-white px-6 py-4 font-bold text-brand-rose">
              Criar meu salão
            </Link>
            <Link href="/baixar" className="rounded-2xl bg-white/15 px-6 py-4 font-bold ring-1 ring-white/30 hover:bg-white/20">
              Baixar os apps (Android)
            </Link>
          </div>
        </div>
      </section>

      <footer className="border-t border-black/5 py-8 text-center text-sm text-brand-muted">
        <div className="flex flex-wrap justify-center gap-5">
          <Link href="/baixar">Baixar os apps</Link>
          <Link href="/privacidade">Privacidade</Link>
          <Link href="/termos">Termos de uso</Link>
          <Link href="/excluir-conta">Excluir conta</Link>
        </div>
        <p className="mt-3">© {new Date().getFullYear()} Salão Max</p>
      </footer>
    </main>
  );
}
