import type { Metadata, Viewport } from "next";
import { salonName } from "@/lib/pwa-meta";

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const name = await salonName(slug);
  return {
    title: name ? `${name} — agende seu horário` : "Agende seu horário — Salão Max",
    manifest: `/s/${slug}/manifest.webmanifest`,
    appleWebApp: { capable: true, title: name ?? "Agendar", statusBarStyle: "default" },
    icons: { icon: "/pwa/cliente-192.png", apple: "/pwa/cliente-180.png" },
  };
}

export const viewport: Viewport = { themeColor: "#E5267A" };

export default function SalonLayout({ children }: { children: React.ReactNode }) {
  return children;
}
