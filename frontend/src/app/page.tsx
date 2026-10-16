import Link from "next/link";

const FEATURES = [
  ["Agenda inteligente", "Horários livres calculados por profissional, sem encaixes duplicados."],
  ["Agendamento online", "Seu cliente marca pelo celular em 1 minuto, só com nome e telefone."],
  ["Controle de tempo", "Compare o tempo previsto com o tempo real de cada atendimento."],
  ["Produtos e estoque", "Entrada, venda e consumo nos atendimentos, com alerta de estoque baixo."],
  ["Custos e lucro", "Comissões, material, despesas e lucro do período em uma tela."],
  ["Vários salões", "Cada salão tem seus próprios dados, equipe e link de agendamento."],
];

export default function Home() {
  return (
    <main className="mx-auto max-w-5xl px-4 py-12">
      <header className="flex items-center justify-between">
        <span className="text-xl font-bold text-rose-600">Salão Max</span>
        <Link href="/login" className="text-sm font-medium text-zinc-700 hover:text-rose-600">
          Entrar
        </Link>
      </header>

      <section className="py-16 text-center">
        <h1 className="text-4xl font-bold tracking-tight text-zinc-900 sm:text-5xl">
          Gestão do seu salão, <span className="text-rose-600">simples e rápida</span>
        </h1>
        <p className="mx-auto mt-4 max-w-2xl text-lg text-zinc-600">
          Agenda, clientes, serviços, produtos, custos e agendamento online — tudo em um só lugar.
        </p>
        <div className="mt-8 flex justify-center gap-3">
          <Link href="/cadastro" className="rounded-lg bg-rose-600 px-5 py-3 font-medium text-white hover:bg-rose-700">
            Criar meu salão grátis
          </Link>
          <Link href="/login" className="rounded-lg border border-zinc-300 bg-white px-5 py-3 font-medium hover:bg-zinc-50">
            Já tenho conta
          </Link>
        </div>
      </section>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {FEATURES.map(([title, text]) => (
          <div key={title} className="rounded-xl border border-zinc-200 bg-white p-5">
            <h3 className="font-semibold">{title}</h3>
            <p className="mt-1 text-sm text-zinc-600">{text}</p>
          </div>
        ))}
      </section>

      <footer className="mt-16 flex flex-wrap justify-center gap-4 text-sm text-zinc-500">
        <Link href="/privacidade">Privacidade</Link>
        <Link href="/termos">Termos de uso</Link>
        <Link href="/excluir-conta">Excluir conta</Link>
      </footer>
    </main>
  );
}
