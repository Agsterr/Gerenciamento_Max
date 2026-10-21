# Push de promoções (Firebase) — app do cliente

Com o Firebase configurado, o aviso de promoção chega **na hora em que ela começa**, mesmo com o app
fechado. Sem configurar, tudo continua funcionando: o app confere as promoções em segundo plano a cada
~2 horas (Android) e quando é aberto.

Como funciona: ao abrir o app (e a cada salão aberto), o celular manda seu código do Firebase ao salão
(`POST /api/public/salons/<slug>/presence`). A cada 5 minutos o servidor procura promoções que começaram,
com "Avisar os clientes no celular" ligado, e manda **uma vez** para os celulares que não desligaram os
avisos. Tocar abre o salão com o serviço da promoção e os horários livres.

## Uma vez só

1. https://console.firebase.google.com → **Criar projeto** (pode desligar o Google Analytics).
2. No projeto: **Adicionar app → Android**, pacote `io.github.agsterr.salaomax.cliente`.
   Baixe o `google-services.json` só para copiar os valores abaixo (não precisa ir para o repositório).
3. GitHub → repositório → *Settings → Secrets and variables → Actions* → **New repository secret**:
   | Secret | De onde vem (no `google-services.json`) |
   |---|---|
   | `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
   | `FIREBASE_APP_ID_CLIENTE` | `client[0].client_info.mobilesdk_app_id` |
   | `FIREBASE_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |
4. Firebase → ⚙️ *Configurações do projeto → Contas de serviço* → **Gerar nova chave privada** (JSON).
   No servidor, no `.env` (nunca no repositório):
   `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64=` + saída de `base64 -w0 arquivo.json`, e reinicie (`docker compose up -d`).
5. Faça qualquer push na `main` (ou rode os workflows *Play Store* / *App (APK)*) para os apps saírem com o push.

iPhone: exige chave APNs da Apple (conta de desenvolvedor) — ainda não configurado.
