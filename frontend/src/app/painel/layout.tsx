"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAuth } from "@/lib/auth";

const NAV = [
  { href: "/painel", label: "Agenda", ownerOnly: false },
  { href: "/painel/clientes", label: "Clientes", ownerOnly: false },
  { href: "/painel/servicos", label: "Serviços", ownerOnly: false },
  { href: "/painel/profissionais", label: "Profissionais", ownerOnly: false },
  { href: "/painel/produtos", label: "Produtos", ownerOnly: false },
  { href: "/painel/financeiro", label: "Financeiro", ownerOnly: true },
  { href: "/painel/configuracoes", label: "Configurações", ownerOnly: true },
];

export default function PanelLayout({ children }: { children: React.ReactNode }) {
  const { user, ready, signOut } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (ready && !user) router.replace("/login");
  }, [ready, user, router]);

  if (!user) return <p className="p-8 text-center text-zinc-500">Carregando...</p>;

  const items = NAV.filter((n) => !n.ownerOnly || user.role === "OWNER");

  return (
    <div className="min-h-screen md:flex">
      <aside className="border-b border-zinc-200 bg-white md:sticky md:top-0 md:h-screen md:w-56 md:shrink-0 md:border-b-0 md:border-r">
        <div className="flex items-center justify-between px-4 py-3 md:block md:py-5">
          <Link href="/painel" className="text-lg font-bold text-rose-600">
            Salão Max
          </Link>
          <button
            onClick={() => {
              signOut();
              router.push("/login");
            }}
            className="text-sm text-zinc-500 hover:text-rose-600 md:hidden"
          >
            Sair
          </button>
        </div>
        <nav className="flex gap-1 overflow-x-auto px-2 pb-2 md:flex-col md:px-3">
          {items.map((n) => {
            const active = n.href === "/painel" ? pathname === n.href : pathname.startsWith(n.href);
            return (
              <Link
                key={n.href}
                href={n.href}
                className={`whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium ${
                  active ? "bg-rose-50 text-rose-700" : "text-zinc-600 hover:bg-zinc-100"
                }`}
              >
                {n.label}
              </Link>
            );
          })}
        </nav>
        <div className="hidden px-4 py-4 text-sm md:absolute md:bottom-0 md:block">
          <p className="font-medium text-zinc-800">{user.name}</p>
          <button
            onClick={() => {
              signOut();
              router.push("/login");
            }}
            className="text-zinc-500 hover:text-rose-600"
          >
            Sair
          </button>
        </div>
      </aside>
      <main className="mx-auto w-full max-w-6xl flex-1 p-4 md:p-8">{children}</main>
    </div>
  );
}
