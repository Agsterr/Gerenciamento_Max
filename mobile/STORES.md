# Publicação na Google Play e na App Store

Checklist do que **já está feito no código** (✅) e do que **você precisa fazer no console da loja** (☐).

## 1. Requisitos comuns

- ✅ **Política de privacidade** pública em `SITE_URL/privacidade` e acessível dentro dos dois apps
  (cliente: *Sobre*; gestão: tela de login e *Ajustes*). Exigida pelas duas lojas.
  ☐ Preencha `NEXT_PUBLIC_LEGAL_COMPANY` e `NEXT_PUBLIC_LEGAL_EMAIL` no site antes de publicar.
- ✅ **Exclusão de conta** (App Store 5.1.1(v) e política de dados do Google Play):
  - dentro do app Gestão: *Ajustes → Excluir conta* (pede a senha; apaga o salão inteiro se for o último dono);
  - pela web, sem instalar o app: `SITE_URL/excluir-conta` (o Google exige esse link).
  - O app Cliente **não cria conta**. Mesmo assim tem *Sobre → Apagar dados deste aparelho* e e-mail de contato
    para pedir exclusão dos dados no salão.
- ✅ **Somente HTTPS em produção**: o Android release não permite tráfego em texto puro (só o build de debug libera,
  via `src/debug/AndroidManifest.xml`); no iOS o ATS só libera rede local (`NSAllowsLocalNetworking`).
  ☐ Publique a API atrás de HTTPS (ex.: certificado Let's Encrypt).
- ✅ **Sem rastreamento, anúncios, localização, câmera ou contatos.** A única permissão Android do build da loja
  (flavor `play`) é `INTERNET` — `REQUEST_INSTALL_PACKAGES` só existe no APK do site (flavor `direct`, §2.1);
  no iOS não há pedido de permissão (nenhum `NS...UsageDescription` necessário).
- ✅ Credenciais protegidas: o JWT do app Gestão fica no Keychain/Keystore (`flutter_secure_storage`) e o
  backup do Android está desativado para ele.
- ✅ Apps nativos (não são *webview* do site) com funções próprias: agendamentos salvos no aparelho, busca,
  agenda com ações rápidas e WhatsApp — atende App Store 4.2 (funcionalidade mínima).
- ✅ Ícones, ícone adaptativo e monocromático (Android 13), splash nativa e artes das lojas prontos (`brand/`, `store/`).
- ☐ Contas de demonstração para a revisão (veja §4).

## 2. Google Play

| Item | Situação |
|---|---|
| `targetSdk` / `compileSdk` **36** (Android 16), `minSdk` 24 | ✅ `android/app/build.gradle.kts` |
| Formato **AAB** (`flutter build appbundle --flavor play`) | ✅ |
| Assinatura de upload via `key.properties` + **Play App Signing** | ✅ configurado / ☐ gerar a chave e ativar no console |
| Páginas de memória de **16 KB** (exigido para apps com código nativo) | ✅ engine Flutter 3.47 compatível; plugins usados não trazem `.so` próprio |
| *Predictive back* (`enableOnBackInvokedCallback`) e *edge-to-edge* | ✅ |
| `<queries>` para abrir WhatsApp/links/e-mail no Android 11+ | ✅ |
| R8/minificação no release | ✅ |
| ID de pacote único (`io.github.agsterr.salaomax.*`, sem `com.example`) | ✅ |
| Ficha: título ≤30, descrição curta ≤80, ícone 512, arte 1024×500, prints 1080×1920 | ✅ prontos em `store/<app>/android/` |
| ☐ **Teste fechado**: contas pessoais criadas após nov/2023 precisam de **12 testadores por 14 dias** antes de produção | console |
| ☐ Questionário de classificação de conteúdo (resposta: sem conteúdo sensível) | console |
| ☐ Público-alvo: **18+** (não é app para crianças) | console |
| ☐ *Acesso ao app*: informar a conta demo do app Gestão | console |
| ☐ URL de exclusão de conta: `SITE_URL/excluir-conta` | console → Segurança dos dados |

### 2.1 Envie sempre o flavor `play`

O app também é distribuído por fora da loja (APK no site, flavor `direct`, com auto-update). **Para a Play use
só o flavor `play`:**
```bash
flutter build appbundle --release --flavor play --dart-define=DISTRIBUTION=play --dart-define=API_URL=... --dart-define=SITE_URL=...
```
- O `play` não tem `REQUEST_INSTALL_PACKAGES`, `FileProvider` de APK nem o canal nativo do instalador, e o código
  Dart de auto-update fica desligado (`DISTRIBUTION=play`). A Play reprova apps que se atualizam por fora da loja
  (política *Device and Network Abuse*) e pede justificativa para `REQUEST_INSTALL_PACKAGES`.
- ☐ Antes de enviar, confira no Play Console (*App bundle explorer → Permissões*) que só aparece `INTERNET`.
- O `applicationId` é o mesmo nos dois canais. Com Play App Signing a assinatura da loja é diferente da do APK do
  site: quem instalou por um canal precisa desinstalar para passar para o outro.

### Formulário "Segurança dos dados" — respostas sugeridas

**Salão Max (cliente)**
- Coleta dados? **Sim**. Compartilha com terceiros? **Não**. Criptografado em trânsito? **Sim**.
- Usuário pode pedir exclusão? **Sim** (e-mail de contato; dados locais apagáveis no app).
- Tipos: **Informações pessoais → Nome** e **Número de telefone** — coletados, obrigatórios,
  finalidade **Funcionalidade do app** (agendamento). Nada de localização, IDs de publicidade ou analytics.

**Salão Max Gestão**
- Coleta dados? **Sim**. Compartilha? **Não**. Criptografado em trânsito? **Sim**. Exclusão: **Sim** (no app e na web).
- Tipos: **Nome**, **E-mail** (conta), **Número de telefone** e **Outras informações** (dados de clientes e do negócio
  cadastrados pelo salão) — finalidade **Funcionalidade do app** e **Gerenciamento de conta**.

## 3. App Store

| Item | Situação |
|---|---|
| Bundle IDs `io.github.agsterr.salaomax.cliente` / `io.github.agsterr.salaomax.gestao` | ✅ / ☐ registrar no developer.apple.com e escolher o *Team* no Xcode |
| **Privacy Manifest** (`ios/Runner/PrivacyInfo.xcprivacy`) com tipos de dados coletados e motivo de API (`UserDefaults` CA92.1 no cliente) | ✅ (os plugins trazem seus próprios manifestos) |
| `ITSAppUsesNonExemptEncryption = false` (só HTTPS; dispensa documentação de exportação) | ✅ `Info.plist` |
| Exclusão de conta dentro do app (5.1.1(v)) | ✅ |
| *Sign in with Apple* | ✅ não necessário: não há login com Google/Facebook (regra 4.8 só se aplica a login social) |
| iOS mínimo 15.0 | ✅ |
| Os dois apps: só iPhone, retrato (dispensa prints de iPad e revisão de layout em tablet; no iPad eles rodam em modo compatível) | ✅ |
| ☐ Rótulos de privacidade no App Store Connect (mesmos dados do manifesto: Nome, Telefone; no Gestão + E-mail e Conteúdo do usuário; **não usados para rastreamento**, **vinculados ao usuário**, finalidade *Funcionalidade do app*) | console |
| ☐ URL de suporte e de política de privacidade na ficha | console |
| Prints 6.9" (1320×2868), textos, palavras-chave e notas da versão | ✅ prontos em `store/<app>/ios/` |

### Pagamentos (atenção à regra 3.1)
O app não vende nada. Se no futuro você **cobrar assinatura dos salões**, não exiba preços, botões ou links de
compra dentro do app iOS (ou use compra in-app da Apple). Cobrar fora e só permitir login no app é aceito
para serviços multiplataforma (3.1.3(b)). Na Play Store vale a política equivalente de *Payments*.

### Evite rejeição por 4.3 (spam)
Mantenha **um** app de cliente para todos os salões (o cliente busca o salão dentro dele). Não publique um app
por salão com o mesmo código (*white-label*) — a Apple rejeita, a menos que cada um seja enviado pela conta do
próprio salão.

## 4. Notas para a revisão (cole nos dois consoles)

> **Salão Max Gestão** — Conta de demonstração: `demo@seudominio.com.br` / `senha-demo`. O salão de teste
> "Salão Demo" já tem profissionais, serviços, produtos e agendamentos. Para excluir a conta: Ajustes → Excluir conta.
>
> **Salão Max** — Não exige login. Na busca digite "Salão Demo", escolha um serviço e um horário e informe
> qualquer nome e telefone (ex.: 11 99999-0000). O agendamento aparece em "Meus horários" e pode ser cancelado.

☐ Crie essa conta e esse salão no ambiente de produção antes de enviar e mantenha-os com dados.

## 5. Nome do app nas lojas

Os nomes nas fichas são **"Salão Max: Agende seu horário"** / **"Salão Max: Agende Beleza"** (cliente) e
**"Salão Max Gestão: Agenda"** / **"Salão Max Gestão"** (salão). Na App Store o nome precisa ser único:
se o App Store Connect disser que já existe, use uma variação como "Salão Max Agenda" ou "Salão Max Beauty".
Evite usar no nome ou nos ícones marcas de terceiros (WhatsApp, Instagram) — nas descrições, citá-las para
explicar uma função é permitido.
