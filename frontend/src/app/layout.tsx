import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";
import { Providers } from "./providers";

const jakarta = localFont({
  src: [
    { path: "./fonts/PlusJakartaSans-Regular.ttf", weight: "400" },
    { path: "./fonts/PlusJakartaSans-Medium.ttf", weight: "500" },
    { path: "./fonts/PlusJakartaSans-SemiBold.ttf", weight: "600" },
    { path: "./fonts/PlusJakartaSans-Bold.ttf", weight: "700" },
    { path: "./fonts/PlusJakartaSans-ExtraBold.ttf", weight: "800" },
  ],
  variable: "--font-jakarta",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Salão Max — agenda e agendamento online para salões de beleza",
  description: "Agenda, clientes, serviços, produtos e financeiro do seu salão. Seus clientes agendam online em 1 minuto.",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#E5267A" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={jakarta.variable}>
      <body className="min-h-screen antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
