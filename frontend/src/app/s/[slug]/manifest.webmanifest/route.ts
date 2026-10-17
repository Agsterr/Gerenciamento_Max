import { salonName } from "@/lib/pwa-meta";

/** PWA do cliente, um por salão: o ícone na tela inicial abre direto a página de agendamento dele. */
export async function GET(_req: Request, { params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const name = (await salonName(slug)) ?? "Salão Max";
  const base = `/s/${slug}`;
  const manifest = {
    id: base,
    name: `${name} — agendar horário`,
    short_name: name.length > 14 ? name.slice(0, 14).trim() : name,
    description: `Agende, remarque e veja seus horários em ${name}.`,
    lang: "pt-BR",
    start_url: base,
    scope: base,
    display: "standalone",
    orientation: "portrait",
    background_color: "#FFF7FA",
    theme_color: "#E5267A",
    icons: [
      { src: "/pwa/cliente-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/pwa/cliente-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/pwa/cliente-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
  return new Response(JSON.stringify(manifest), {
    headers: { "Content-Type": "application/manifest+json", "Cache-Control": "public, max-age=3600" },
  });
}
