"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { NotificationBell } from "@/components/NotificationBell";
import { PlanBanner } from "@/components/PlanBanner";
import { InstallAppLink } from "@/components/InstallApp";
import { useAuth } from "@/lib/auth";

const NAV = [
  { href: "/painel", label: "Agenda", ownerOnly: false },
  { href: "/painel/lembretes", label: "Lembretes", ownerOnly: false },
  { href: "/painel/clientes", label: "Clientes", ownerOnly: false },
  { href: "/painel/servicos", label: "Serviços", ownerOnly: false },
  { href: "/painel/profissionais", label: "Profissionais", ownerOnly: false },
  { href: "/painel/produtos", label: "Produtos", ownerOnly: false },
  { href: "/painel/promocoes", label: "Pacotes e promoções", ownerOnly: false },
  { href: "/painel/portfolio", label: "Portfólio", ownerOnly: false },
  { href: "/painel/financeiro", label: "Financeiro e relatórios", ownerOnly: true },
  { href: "/painel/precificacao", label: "Precificação", ownerOnly: true },
  { href: "/painel/configuracoes", label: "Configurações", ownerOnly: true },
];

export function PanelShell({ children }: { children: React.ReactNode }) {
  const { user, ready, signOut } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (ready && !user) router.replace("/login");
    if (user?.role === "PLATFORM_ADMIN") router.replace("/plataforma");
  }, [ready, user, router]);

  if (!user || user.role === "PLATFORM_ADMIN") return <p className="p-8 text-center text-zinc-500">Carregando...</p>;

  const items = NAV.filter((n) => !n.ownerOnly || user.role === "OWNER");

  return (
    <div className="min-h-screen md:flex">
      <aside className="print:hidden border-b border-zinc-200 bg-white md:sticky md:top-0 md:h-screen md:w-56 md:shrink-0 md:border-b-0 md:border-r">
        <div className="flex items-center justify-between px-4 py-3 md:block md:py-5">
          <Link href="/painel" className="flex items-center gap-2 text-lg font-extrabold">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/icon-gestao.png" alt="" className="h-8 w-8 rounded-lg" />
            <span className="text-brand">Salão Max</span>
          </Link>
          <div className="flex items-center gap-2 md:mt-3">
            <NotificationBell />
            <button
              onClick={() => {
                signOut();
                router.push("/login");
              }}
              className="text-sm text-zinc-500 hover:text-brand-rose md:hidden"
            >
              Sair
            </button>
          </div>
        </div>
        <nav className="flex gap-1 overflow-x-auto px-2 pb-2 md:flex-col md:px-3">
          {items.map((n) => {
            const active = n.href === "/painel" ? pathname === n.href : pathname.startsWith(n.href);
            return (
              <Link
                key={n.href}
                href={n.href}
                className={`whitespace-nowrap rounded-xl px-3 py-2 text-sm font-bold ${
                  active ? "bg-brand text-white shadow-glow" : "text-brand-muted hover:bg-[#FFF1F6]"
                }`}
              >
                {n.label}
              </Link>
            );
          })}
        </nav>
        <div className="hidden px-4 py-4 text-sm md:absolute md:bottom-0 md:block">
          <InstallAppLink app="gestao" className="mb-3 block font-bold text-brand-rose hover:underline" />
          <p className="font-medium text-zinc-800">{user.name}</p>
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
      </aside>
      <main className="mx-auto w-full max-w-6xl flex-1 p-4 md:p-8">
        <PlanBanner key={pathname} />
        {children}
      </main>
    </div>
  );
}
