# Google Play — publicação automática

O workflow **Play Store** (`.github/workflows/play-release.yml`) roda a cada push na
`main` que mexe em `mobile/`: builda o `.aab` do canal `play` dos dois apps e envia para a faixa de
**teste fechado (Alpha)**, onde estão os testadores. Para mudar a faixa sem editar o arquivo, crie a variável do repositório `PLAY_TRACK` (`internal`, `alpha`, `beta` ou `production`). Sem a conta de serviço configurada, o
`.aab` fica disponível nos *Artifacts* da execução (útil para o primeiro envio manual).

| App | Pacote |
|---|---|
| Salão Max Gestão (salão) | `io.github.agsterr.salaomax.gestao` |
| Salão Max (cliente) | `io.github.agsterr.salaomax.cliente` |

## Uma vez só (no Play Console)

1. **Criar os dois apps** com os pacotes acima. A API da Play não cria apps.
2. **Primeiro `.aab` manual**: rode o workflow (*Actions → Play Store → Run workflow*), baixe o `.aab`
   dos Artifacts e envie em *Testar e lançar → Teste interno*. Aceite o **Assinatura de apps do Google
   Play**: o keystore dos secrets `ANDROID_KEYSTORE_*` vira a chave de upload.
3. **Conta de serviço** (Google Cloud Console, mesmo login da Play):
   - crie um projeto (ou use um existente) e ative a *Google Play Android Developer API*;
   - *IAM → Contas de serviço → Criar*; em *Chaves*, gere uma chave **JSON**;
   - no Play Console, *Usuários e permissões → Convidar usuário* com o e-mail da conta de serviço,
     acesso aos dois apps e permissão de **lançar em faixas de teste** (e produção, se quiser);
   - salve o JSON no GitHub e apague o arquivo local:
     `gh secret set PLAY_SERVICE_ACCOUNT_JSON -R Agsterr/Gerenciamento_Max < chave.json`
4. Enquanto o app nunca passou pela revisão, a Play só aceita envio como **rascunho** (padrão).
   Depois da primeira aprovação, crie a variável do repositório
   `PLAY_RELEASE_STATUS=completed` (*Settings → Secrets and variables → Actions → Variables*).

Conta **pessoal** criada depois de nov/2023: a Play exige **teste fechado com 12 testadores por
14 dias** antes de liberar a produção. Conta de **organização** não tem essa exigência.

## Ficha da loja (manual, uma vez)

Artes e textos em `mobile/store/`, checklist em `mobile/STORES.md`. Política de privacidade:
`https://salaomax.focodev.com.br/privacidade` · exclusão de conta: `/excluir-conta`. Preencher
*Segurança dos dados*, *Classificação do conteúdo* e *Público-alvo*.

## Cobrança e regras da loja

Os apps são gratuitos na loja; o salão assina fora dela. Na versão `play`, o app **não mostra botão,
link nem texto para assinar por fora** (regra de pagamentos da Play e da App Store):

- o app manda `X-App-Channel: play` em toda requisição e a API responde sem falar de plano/assinatura
  (`AppChannel` no backend);
- o aviso de teste grátis no app de gestão aparece sem o botão "Ativar meu plano";
- o APK do site (canal `direct`) e o painel web continuam com o atalho para assinar.

O `versionCode` da Play é `1000 + número da execução` (sempre crescente). O APK do site tem a
numeração própria; como as assinaturas são diferentes (Google re-assina o da Play), trocar de canal
exige desinstalar o app.

## Assinatura mensal dentro do app (Google Play Billing)

Plano único, **R$ 49,90/mês**, só no app **Salão Max Gestão** (o app do cliente continua grátis).
O app compra pela Play e manda o token ao servidor (`POST /api/billing/play/verify`); o servidor
confirma com o Google, reconhece (acknowledge) a compra e libera o plano. Uma rotina diária (05:00)
renova ou vence os salões assinantes (cancelada com prazo restante continua valendo até o fim).

**Seguro para testadores:** a cobrança nasce **desligada**. Em `/plataforma` → *Teste grátis* a chave
*Cobrança na loja* só deve ser ligada no lançamento público. Para testar antes, marque
*Mostrar "Assinar" nos apps deste salão* em *Salões → Plano* — só esse salão vê o botão.

Uma vez só:
1. Play Console → *Monetizar com a Play* → *Produtos* → *Assinaturas*: criar o produto
   `salao_max_mensal` com plano-base mensal, renovação automática, R$ 49,90 (e, se quiser, oferta de
   lançamento). Precisa de perfil de pagamentos. O app precisa estar publicado em alguma faixa.
2. Google Cloud: criar uma *conta de serviço*, ativar a *Google Play Android Developer API* e gerar
   uma chave JSON. No Play Console → *Usuários e permissões*, convidar o e-mail da conta de serviço
   com permissão de ver dados financeiros e gerenciar pedidos/assinaturas.
3. No servidor, `PLAY_SERVICE_ACCOUNT_JSON_BASE64` (`base64 -w0 chave.json`) no `.env`. Nunca no repositório.
4. Testar: *Configurações → Testes de licença* com a conta de teste; marcar o salão de teste como acima.
5. Cancelar a assinatura: pela Play (o app tem o atalho em Ajustes). Excluir a conta do app não cancela a assinatura.
