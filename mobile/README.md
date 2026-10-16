# Apps Flutter

| Pasta | App | Para quem | ID (Android / iOS) |
|---|---|---|---|
| `cliente/` | **Salão Max** | Clientes: buscar o salão, agendar, ver e cancelar horários (sem criar conta) | `com.max.salao.cliente` |
| `gestao/` | **Salão Max Gestão** | Salão: agenda (horários livres, manual e encaixe), clientes, serviços, profissionais, estoque, financeiro, ajustes | `com.max.salao.gestao` |
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

### Ícones
Substitua `assets/icon.png` (1024×1024) e `assets/icon_foreground.png` pela sua marca e rode
`dart run flutter_launcher_icons`.

Requisitos de publicação, respostas dos formulários de privacidade e notas para revisão: **[STORES.md](STORES.md)**.
