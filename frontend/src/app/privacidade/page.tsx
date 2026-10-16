import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = { title: "Política de Privacidade — Salão Max" };

/** URL exigida na ficha da Play Store / App Store e acessível dentro dos apps. */
export default function PrivacyPage() {
  return (
    <LegalPage title="Política de Privacidade">
      <p>Última atualização: {LEGAL.updatedAt}</p>
      <p>
        Esta política explica como {LEGAL.company} trata dados pessoais no site e nos aplicativos
        <strong> Salão Max</strong> (cliente) e <strong>Salão Max Gestão</strong> (salão), em conformidade com a Lei
        Geral de Proteção de Dados (Lei 13.709/2018).
      </p>

      <h2>Dados que coletamos</h2>
      <ul>
        <li>
          <strong>Clientes que agendam:</strong> nome, telefone (WhatsApp), e-mail opcional, serviços agendados e
          histórico de atendimentos no salão escolhido.
        </li>
        <li>
          <strong>Usuários do salão:</strong> nome, e-mail e senha (armazenada apenas como hash criptográfico).
        </li>
        <li>
          <strong>Dados do negócio:</strong> serviços, preços, profissionais, produtos, estoque e despesas cadastrados
          pelo salão.
        </li>
      </ul>
      <p>
        Não coletamos localização, contatos, fotos, identificadores de publicidade nem dados de pagamento. Os apps não
        usam rastreamento entre apps e sites de terceiros nem exibem anúncios.
      </p>

      <h2>Para que usamos</h2>
      <ul>
        <li>Realizar, confirmar, remarcar e cancelar agendamentos (execução de contrato).</li>
        <li>Permitir que o salão gerencie agenda, clientes, estoque e finanças (execução de contrato).</li>
        <li>Segurança da conta e prevenção de fraudes (legítimo interesse).</li>
      </ul>

      <h2>Compartilhamento</h2>
      <p>
        Os dados de um agendamento são visíveis apenas para o salão escolhido pelo cliente. Não vendemos nem
        compartilhamos dados com terceiros, exceto provedores de infraestrutura (hospedagem) sob contrato e quando
        exigido por lei. Toda comunicação é feita por conexão criptografada (HTTPS).
      </p>

      <h2>Armazenamento no aparelho</h2>
      <p>
        O app do cliente guarda no próprio aparelho os códigos dos seus agendamentos para exibir em “Meus
        agendamentos”. O app do salão guarda o token de acesso em armazenamento seguro do sistema (Keychain/Keystore).
      </p>

      <h2>Retenção e exclusão</h2>
      <ul>
        <li>
          <strong>Conta do salão:</strong> pode ser excluída a qualquer momento no app (Configurações → Excluir conta)
          ou em <a className="text-brand-rose underline" href="/excluir-conta">/excluir-conta</a>. Se for o último dono, o
          salão e todos os seus dados são apagados imediatamente e de forma definitiva.
        </li>
        <li>
          <strong>Clientes:</strong> o salão é o controlador dos dados do seu cadastro. Para excluir seus dados, peça ao
          salão ou escreva para {LEGAL.email}; atendemos em até 15 dias. Os agendamentos salvos no app podem ser
          apagados no próprio app.
        </li>
      </ul>

      <h2>Seus direitos</h2>
      <p>
        Você pode solicitar confirmação, acesso, correção, anonimização, portabilidade e exclusão dos seus dados, bem
        como revogar consentimentos (art. 18 da LGPD), pelo e-mail <strong>{LEGAL.email}</strong>.
      </p>

      <h2>Crianças</h2>
      <p>Os serviços não são direcionados a menores de 13 anos.</p>

      <h2>Contato</h2>
      <p>
        Encarregado de dados (DPO): {LEGAL.company} — {LEGAL.email}
      </p>
    </LegalPage>
  );
}
