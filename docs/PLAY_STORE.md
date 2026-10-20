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
