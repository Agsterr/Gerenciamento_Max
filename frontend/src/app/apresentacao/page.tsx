import type { Metadata } from "next";
import { Presentation } from "@/components/Presentation";

export const metadata: Metadata = {
  metadataBase: new URL("https://salaomax.focodev.com.br"),
  title: "Conheça o Salão Max",
  description: "Agenda e agendamento online para salões: veja como funciona para o salão, para o cliente e para quem indica.",
  openGraph: {
    title: "Conheça o Salão Max",
    description: "Agenda, agendamento online, estoque e financeiro para o seu salão. Teste grátis.",
    images: ["/icon-cliente.png"],
  },
};

/** Apresentação digital: salão, cliente e representante, num link só. */
export default function PresentationPage() {
  return <Presentation />;
}
