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
| `SUPPORT_EMAIL` | E-mail de contato/privacidade exibido no app |

Testes e análise:
```bash
for d in core cliente gestao; do (cd $d && flutter analyze && flutter test); done
```

## Build de produção

```bash
DEFINES="--dart-define=API_URL=https://api.seudominio.com.br --dart-define=SITE_URL=https://seudominio.com.br --dart-define=SUPPORT_EMAIL=contato@seudominio.com.br"

flutter build appbundle --release $DEFINES   # Google Play (.aab)
flutter build ipa --release $DEFINES         # App Store (requer macOS + Xcode)
```

Antes de cada envio, aumente o número de build em `pubspec.yaml` (`version: 1.0.0+2`).

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
Sem esse arquivo o release é assinado com a chave de debug (serve só para teste local).

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
