# Pagamentos e representantes

Duas formas de a pessoa assinar o Salão Max, as duas gerando o mesmo plano pago. O preço da Play é mais alto
(**R$ 58,90** contra **R$ 49,90** no site) para cobrir a taxa da loja (~15%) e sobrar o mesmo líquido:

| Onde | Como | Quem cobra |
|---|---|---|
| **Site** (`/painel/assinatura`, "Meu plano") | Pix, boleto ou cartão, R$ 49,90 | Asaas |
| **App de gestão na Play Store** | assinatura da loja, R$ 58,90 | Google Play (`docs/PLAY_STORE.md`) |

O plano vale até o fim do período pago (+1 dia de folga). Cancelar não derruba na hora: o acesso segue até o vencimento.
Quem assinou pelo app não vê o botão do site, e vice-versa (regra de pagamentos da Google). Não mostre o preço do site
dentro do app da loja.

## Como funciona o pagamento pelo site (Asaas)

O botão **Assinar pelo site** cria um *link de pagamento recorrente mensal* no Asaas e abre a página dele: a pessoa
informa os dados e escolhe Pix, boleto ou cartão. **Cartão renova sozinho**; **Pix e boleto** o Asaas manda por e-mail
todo mês, e o plano é estendido quando o pagamento é confirmado (boleto pode levar 1 a 3 dias). O Asaas avisa o
servidor por webhook; cada pagamento confirmado/recebido estende o plano e gera a comissão do representante.
**Cancelar assinatura** (botão em "Meu plano") cancela a cobrança no Asaas.

> A API do Asaas foi integrada pela referência pública que o código usa (links de pagamento, webhook com o cabeçalho
> `asaas-access-token`, eventos `PAYMENT_CONFIRMED`, `PAYMENT_RECEIVED`, `PAYMENT_REFUNDED`,
> `PAYMENT_CHARGEBACK_REQUESTED`). **Teste primeiro no sandbox** antes de ligar para clientes (passo a passo abaixo).

## Ligar (uma vez)

1. **Sandbox (teste):** crie uma conta em https://sandbox.asaas.com, gere a chave de API (Integrações → Chave de API) e,
   no `.env` do servidor, coloque `ASAAS_API_KEY`, um `ASAAS_WEBHOOK_TOKEN` inventado por você (32+ caracteres, sem
   espaços) e `ASAAS_BASE_URL=https://api-sandbox.asaas.com/v3`.
2. No Asaas (Integrações → Webhooks → Novo webhook): URL `https://salaomax.focodev.com.br/api/asaas/webhook`, o mesmo
   token em "Token de autenticação", fila ativa, eventos de **Cobranças** (ao menos pagamento confirmado, recebido,
   estornado e chargeback).
3. `docker compose up -d`, abra **Meu plano** num salão de teste, clique em **Assinar pelo site**, pague no sandbox e
   confira que o plano ficou ativo e que a comissão apareceu para o representante.
4. **Produção:** repita com a conta de produção (chave de API de produção, `ASAAS_BASE_URL=https://api.asaas.com/v3`,
   webhook novo na conta de produção). Se a sua conta Asaas já tem webhook de outro sistema (o de estoque), crie um
   webhook separado para esta URL, com um token só dele.

Sem `ASAAS_API_KEY` e `ASAAS_WEBHOOK_TOKEN`, o botão do site não aparece. A chave e o token ficam só no servidor.

## Representantes

- Qualquer pessoa se cadastra em **/representantes** e recebe um **código** e um **link** (`/r/CODIGO`).
- O salão que abrir o link e se cadastrar fica ligado àquele representante (só no cadastro; não muda depois).
- **Cada mensalidade paga** desse salão (site ou Play) gera **R$ 15,00** de comissão (`REFERRAL_COMMISSION_CENTS`).
- **Cancelou**: os próximos meses não geram comissão; o que já foi pago continua do representante.
- **Estornou ou contestou** (estorno, chargeback; na Play, pedido anulado): aquela comissão é perdida.
- A comissão fica **em espera por 7 dias** (`REFERRAL_HOLD_DAYS`, prazo de arrependimento/estorno) e depois fica
  **disponível**. O administrador faz o Pix e clica **Marcar como pago** em *Plataforma → Representantes*.
- O representante vê no painel (`/representante`): link, salões indicados (pagando / em teste / vencido), comissões
  (em espera, disponível, pago, estornado) e informa a chave Pix.

Limitação conhecida: se um estorno acontecer *depois* de a comissão já ter sido repassada, ela aparece como estornada, mas
não há desconto automático do próximo repasse (faça o acerto à mão).

## Preço na Play

O valor se muda no Play Console (plano base da assinatura `salao_max_mensal`), não no código. `PLAY_PRICE_CENTS` (padrão
5890) é só o valor de referência guardado no registro de pagamentos; mantenha igual ao do Play Console. O preço do site
(`ASAAS_PRICE_CENTS`, padrão 4990) vai no link de pagamento criado no Asaas.
