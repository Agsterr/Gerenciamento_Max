import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = { title: "Termos de Uso — Salão Max" };

export default function TermsPage() {
  return (
    <LegalPage title="Termos de Uso">
      <p>Última atualização: {LEGAL.updatedAt}</p>
      <h2>O serviço</h2>
      <p>
        O Salão Max é uma ferramenta para salões de beleza organizarem agenda, clientes, produtos e finanças, e para
        clientes agendarem horários online. O atendimento em si é de responsabilidade exclusiva de cada salão.
      </p>
      <h2>Contas</h2>
      <p>
        O salão é responsável pelas informações que cadastra, por manter sua senha em sigilo e pelos acessos que concede
        à equipe. A conta pode ser excluída a qualquer momento pelo app ou pelo site.
      </p>
      <h2>Agendamentos</h2>
      <p>
        O cliente pode cancelar pelo app ou link até 2 horas antes do horário. Depois disso, deve falar diretamente com o
        salão. Políticas de atraso, falta e pagamento são definidas por cada salão.
      </p>
      <h2>Uso adequado</h2>
      <p>É proibido usar o serviço para spam, fraude, agendamentos falsos ou qualquer atividade ilegal.</p>
      <h2>Contato</h2>
      <p>{LEGAL.email}</p>
    </LegalPage>
  );
}
