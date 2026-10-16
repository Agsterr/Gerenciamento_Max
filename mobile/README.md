# Apps Flutter

| Pasta | App | Para quem | ID (Android / iOS) |
|---|---|---|---|
| `cliente/` | **Salão Max** | Clientes: buscar o salão, agendar, ver e cancelar horários (sem criar conta) | `io.github.agsterr.salaomax.cliente` |
| `gestao/` | **Salão Max Gestão** | Salão: agenda (horários livres, manual e encaixe), clientes, serviços, profissionais, estoque, financeiro, ajustes | `io.github.agsterr.salaomax.gestao` |
| `core/` | pacote `salao_core` | Cliente HTTP, modelos, formatação, tema e widgets compartilhados | — |

Dois apps separados (em vez de *flavors*) porque têm públicos, ícones e fichas de loja diferentes, e
assim cada um fica simples. O código comum mora em `core/`. Gerenciamento de estado é só
`StatefulWidget` + um `ChangeNotifier` de sessão, sem frameworks extras.

## Rodando

Pré-requisitos: Flutter 3.35+ (testado com 3.47), Android Studio e/ou Xcode, e a API rodando (veja o README da raiz).

```bash
cd mobile/cliente   # ou mobile/gestao
flutter pub get

# Emulador Android (10.0.2.2 = localhost da sua máquina)
flutter run --dart-define=API_URL=http://10.0.2.2:8080 --dart-define=SITE_URL=http://10.0.2.2:3000

# Simulador iOS
flutter run --dart-define=API_URL=http://localhost:8080 --dart-define=SITE_URL=http://localhost:3000
```

| `--dart-define` | Uso |
|---|---|
| `API_URL` | URL da API (em produção **obrigatoriamente HTTPS**) |
| `SITE_URL` | Site Next.js: links de política de privacidade, termos e exclusão de conta, e o link público do salão |
| `SUPPORT_EMAIL` | E-mail de contato/privacidade exibido no app (e na tela de conta bloqueada) |
| `DISTRIBUTION` | `play` (padrão) ou `direct` — canal de distribuição, junto com `--flavor` (veja abaixo) |

`flutter run` sem `--flavor` usa o flavor `play` (`default-flavor` no `pubspec.yaml`). Para testar o auto-update:
`flutter run --flavor direct --dart-define=DISTRIBUTION=direct --dart-define=API_URL=...`.

Testes e análise:
```bash
for d in core cliente gestao; do (cd $d && flutter analyze && flutter test); done
```

## Build de produção

```bash
DEFINES="--dart-define=API_URL=https://api.seudominio.com.br --dart-define=SITE_URL=https://seudominio.com.br --dart-define=SUPPORT_EMAIL=contato@seudominio.com.br"

flutter build appbundle --release --flavor play --dart-define=DISTRIBUTION=play $DEFINES   # Google Play (.aab)
flutter build apk --release --flavor direct --dart-define=DISTRIBUTION=direct $DEFINES     # APK do site (auto-update)
flutter build ipa --release $DEFINES         # App Store (requer macOS + Xcode; iOS não tem auto-update)
```

Antes de cada envio, aumente o número de build em `pubspec.yaml` (`version: 1.0.0+2`).

### Dois canais no Android: Play Store e APK do site

Os dois apps têm os *product flavors* `play` e `direct`, com o **mesmo `applicationId`** (um APK do site
atualiza por cima de outro APK do site; trocar entre Play e site exige a mesma chave de assinatura).

| | `play` (Google Play) | `direct` (APK baixado do site) |
|---|---|---|
| Build | `--flavor play --dart-define=DISTRIBUTION=play` → `.aab` | `--flavor direct --dart-define=DISTRIBUTION=direct` → `build/app/outputs/flutter-apk/app-direct-release.apk` |
| Atualização | pela loja | pelo próprio app |
| `REQUEST_INSTALL_PACKAGES` / instalador | **não** (o `src/play/AndroidManifest.xml` ainda remove a permissão se alguma lib trouxer) | sim (`src/direct/`: permissão, `FileProvider` e canal nativo `salaomax/apk_installer`) |

A Play Store reprova apps com `REQUEST_INSTALL_PACKAGES` ou que se atualizam por fora da loja — por isso
tudo do auto-update fica no flavor `direct`. `DISTRIBUTION` liga o código Dart; sem o define, vale o `--flavor`.

**Como funciona o auto-update** (`core/lib/src/update/`, usado pelos dois apps):
1. Ao abrir o app e ao voltar para ele, `AppUpdateListener` chama
   `GET {API_URL}/api/app/version?app=gestao|cliente` → `{versionName, versionCode, downloadUrl, releaseNotes, forceUpdate, sha256}`
   (404 = nada publicado, silencioso; sem rede, silencioso).
2. Se `versionCode` > `buildNumber` instalado: diálogo **"Atualização disponível"** (pode adiar), ou, com
   `forceUpdate`, tela cheia **"Atualização obrigatória"** que não fecha e já começa a baixar.
3. Baixa o APK com progresso, confere o `sha256` e abre o instalador do Android. Na primeira vez o Android pede
   para liberar "instalar apps desconhecidos" para o Salão Max.
4. Em *Ajustes* (gestão) e *Sobre* (cliente) aparecem a versão instalada e **"Verificar atualização"**.

A publicação é automática: o workflow `.github/workflows/mobile-release.yml` builda o flavor `direct` a cada push
na `main` que mexe em `mobile/**` e envia o APK para a API (veja `docs/DEPLOY.md`).

### Conta bloqueada (app Gestão)
Quando qualquer resposta da API vem `403` com `"code": "ACCOUNT_BLOCKED"` (ProblemDetail; motivo em `detail`),
o `ApiClient` chama `onAccountBlocked` e lança `AccountBlockedException`. O app Gestão apaga o token e mostra a
tela "Sua conta foi bloqueada" (motivo, e-mail de `SUPPORT_EMAIL` e "Sair"), inclusive no login. Vale nos dois flavors.

### Assinatura Android
```bash
keytool -genkey -v -keystore ~/upload-salao-cliente.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Crie `android/key.properties` (já está no `.gitignore` — **nunca versione**):
```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/caminho/upload-salao-cliente.jks
```
`storeFile` relativo é resolvido a partir de `android/app` (o CI grava `storeFile=upload-keystore.jks`).
Sem esse arquivo o release é assinado com a chave de debug (serve só para teste local).
Use a **mesma chave** para o flavor `play` e o `direct` se quiser que o usuário possa trocar de canal sem desinstalar
(com Play App Signing, a chave que assina o app da loja é a do Google — aí o APK do site e o da loja não se atualizam
um por cima do outro; o usuário precisa desinstalar para trocar).

### Assinatura iOS
Abra `ios/Runner.xcworkspace` no Xcode → *Signing & Capabilities* → selecione o seu *Team*. Os bundle IDs
já estão configurados; registre-os em developer.apple.com.

### IDs de pacote
`io.github.agsterr.salaomax.cliente` e `io.github.agsterr.salaomax.gestao` usam o seu usuário do GitHub
como domínio invertido: são únicos (ninguém mais pode ter esse prefixo legitimamente) e a Play Store e a App Store
aceitam. **O ID não pode ser trocado depois do primeiro envio.** Se você registrar um domínio próprio
(ex.: `salaomax.com.br`) e preferir `br.com.salaomax.cliente`, troque **antes** de publicar em:
`android/app/build.gradle.kts` (`namespace` e `applicationId`), a pasta do `MainActivity.kt` e
`PRODUCT_BUNDLE_IDENTIFIER` em `ios/Runner.xcodeproj/project.pbxproj`.

### Identidade visual
- Logos em vetor: `brand/symbol-*.svg` e `brand/background-*.svg`. Para regerar os PNGs:
  `node brand/render-icons.mjs` e depois, em cada app, `dart run flutter_launcher_icons` e
  `dart run flutter_native_splash:create`.
- Fonte: Plus Jakarta Sans (licença OFL, livre para uso comercial) embutida em `core/fonts`.
- Tema, gradientes e componentes (`GradientHeader`, `SoftCard`, `GradientButton`, `InitialsAvatar`...) em
  `core/lib/src/theme.dart` e `core/lib/src/widgets.dart`.

### Fichas das lojas (textos, prints, ícone e arte de destaque)
Tudo em `store/`, já no layout do [fastlane](https://fastlane.tools) (`supply` para a Play, `deliver` para a App Store):
```
store/<app>/android/pt-BR/{title,short_description,full_description}.txt
store/<app>/android/pt-BR/images/{icon.png (512), featureGraphic.png (1024×500), phoneScreenshots/*.png (1080×1920)}
store/<app>/ios/pt-BR/{name,subtitle,keywords,description,promotional_text,release_notes}.txt
store/<app>/ios/screenshots/pt-BR/*.png  (iPhone 6.9", 1320×2868)
```
Para regerar os prints: capture as telas em `store/tools/raw/` e rode `node store/tools/compose.mjs`
(títulos em `store/tools/screens.json`).

Requisitos de publicação, respostas dos formulários de privacidade e notas para revisão: **[STORES.md](STORES.md)**.
