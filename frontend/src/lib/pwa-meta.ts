import type { Metadata } from "next";

/** Metadados do PWA do salão (painel, login e cadastro). */
export const gestaoPwa: Metadata = {
  manifest: "/gestao.webmanifest",
  appleWebApp: { capable: true, title: "Max Gestão", statusBarStyle: "black-translucent" },
  icons: { icon: "/pwa/gestao-192.png", apple: "/pwa/gestao-180.png" },
};

/** Endereço da API visto pelo servidor do site (dentro do Docker é o container "api"). */
export const serverApiUrl = process.env.API_INTERNAL_URL ?? process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080";

/** Nome do salão para o ícone do app do cliente; sem resposta rápida da API, usa um nome genérico. */
export async function salonName(slug: string): Promise<string | null> {
  try {
    const res = await fetch(`${serverApiUrl}/api/public/salons/${encodeURIComponent(slug)}`, {
      next: { revalidate: 3600 },
      signal: AbortSignal.timeout(2000),
    });
    if (!res.ok) return null;
    return ((await res.json()) as { name: string }).name;
  } catch {
    return null;
  }
}
