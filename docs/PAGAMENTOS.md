# Pagamentos e representantes

Duas formas de a pessoa assinar o Salão Max (R$ 49,90/mês), as duas gerando o mesmo plano pago:

| Onde | Como | Quem cobra |
|---|---|---|
| **Site** (`/painel/assinatura`, "Meu plano") | cartão, tela de pagamento do Stripe | Stripe Billing |
| **App de gestão na Play Store** | assinatura da loja | Google Play (já configurado, `docs/PLAY_STORE.md`) |

O plano vale até o fim do período pago (+1 dia de folga). Cancelar não derruba na hora: o acesso segue até o vencimento.
Quem assina pelo app não vê o botão do site, e vice-versa (regra de pagamentos da Google).

> Por que Stripe e não RevenueCat: o RevenueCat só soma valor quando se precisa juntar *várias* lojas (Play + App Store +
> web) num lugar só. Aqui a Play já está integrada direto e o site é um só, então o RevenueCat acrescentaria cobrança
> (1% sobre a receita) e outra dependência sem trazer nada. Se um dia entrar a App Store, vale reavaliar.

## Ligar o pagamento pelo site (uma vez)

1. Conta em https://dashboard.stripe.com (Brasil). Em **Produtos**, crie o produto *Salão Max* com preço **recorrente
   mensal de R$ 49,90** e copie o ID do preço (`price_...`).
2. Em **Desenvolvedores → Chaves de API**, copie a **chave secreta** (`sk_live_...`; use `sk_test_...` para testar).
3. Em **Desenvolvedores → Webhooks → Adicionar endpoint**: URL `https://salaomax.focodev.com.br/api/stripe/webhook`,
   eventos `checkout.session.completed`, `invoice.paid`, `charge.refunded`, `charge.dispute.created` e
   `customer.subscription.deleted`. Copie o **segredo de assinatura** (`whsec_...`).
4. Em **Configurações → Billing → Portal do cliente**, ligue o portal e permita *cancelar assinatura* e *atualizar forma
   de pagamento*.
5. No `.env` do servidor (nunca no repositório): `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID`, `STRIPE_WEBHOOK_SECRET`;
   depois `docker compose up -d`. Sem as três, o botão do site não aparece.

## Representantes

- Qualquer pessoa se cadastra em **/representantes** e recebe um **código** e um **link** (`/r/CODIGO`).
- O salão que abrir o link e se cadastrar fica ligado àquele representante (só no cadastro; não muda depois).
- **Cada mensalidade paga** desse salão (site ou Play) gera **R$ 15,00** de comissão (`REFERRAL_COMMISSION_CENTS`).
- **Cancelou**: os próximos meses não geram comissão; o que já foi pago continua do representante.
- **Estornou ou contestou** (reembolso total, chargeback; na Play, pedido anulado): aquela comissão é perdida.
- A comissão fica **em espera por 7 dias** (`REFERRAL_HOLD_DAYS`, prazo de arrependimento/estorno) e depois fica
  **disponível**. O administrador faz o Pix e clica **Marcar como pago** em *Plataforma → Representantes*.
- O representante vê no painel (`/representante`): link, salões indicados (pagando / em teste / vencido), comissões
  (em espera, disponível, pago, estornado) e informa a chave Pix.

Limitação conhecida: se um estorno acontecer *depois* de a comissão já ter sido repassada, ela aparece como estornada, mas
não há desconto automático do próximo repasse (faça o acerto à mão).
