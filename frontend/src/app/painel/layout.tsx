import { PanelShell } from "@/components/PanelShell";
import { gestaoPwa } from "@/lib/pwa-meta";

export const metadata = gestaoPwa;

export default function PanelLayout({ children }: { children: React.ReactNode }) {
  return <PanelShell>{children}</PanelShell>;
}
