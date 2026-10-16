import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Providers } from "./providers";

export const metadata: Metadata = {
  title: "Salão Max — gestão de salão de beleza",
  description: "Agenda, clientes, serviços, produtos e financeiro do seu salão. Agendamento online para clientes.",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#e11d48" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body className="min-h-screen antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
