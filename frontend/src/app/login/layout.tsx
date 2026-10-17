import { gestaoPwa } from "@/lib/pwa-meta";

export const metadata = gestaoPwa;

export default function Layout({ children }: { children: React.ReactNode }) {
  return children;
}
