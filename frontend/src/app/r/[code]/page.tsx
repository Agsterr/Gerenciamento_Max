import type { Metadata } from "next";
import { Presentation } from "@/components/Presentation";

export const metadata: Metadata = {
  metadataBase: new URL("https://salaomax.focodev.com.br"),
  title: "Convite: conheça o Salão Max",
  description: "Você foi convidado a conhecer o Salão Max: agenda e agendamento online para o seu salão. Teste grátis.",
  openGraph: {
    title: "Convite: conheça o Salão Max",
    description: "Agenda, agendamento online, estoque e financeiro para o seu salão. Teste grátis.",
    images: ["/icon-cliente.png"],
  },
};

/** Link do representante (/r/CODIGO): apresentação do Salão Max; o código segue sozinho para o cadastro do salão. */
export default async function ReferralLink({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const ref = String(code).toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 20);
  return <Presentation code={ref || undefined} audiences={["salao", "cliente"]} />;
}
