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
2. No projeto: **Adicionar app → Android** duas vezes: `io.github.agsterr.salaomax.cliente` (clientes) e
   `io.github.agsterr.salaomax.gestao` (salão/profissionais). Baixe o `google-services.json` de cada um só para
   copiar os valores abaixo (não precisa ir para o repositório).
3. GitHub → repositório → *Settings → Secrets and variables → Actions* → **New repository secret**:
   | Secret | De onde vem (no `google-services.json`) |
   |---|---|
   | `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
   | `FIREBASE_APP_ID_CLIENTE` | `client[0].client_info.mobilesdk_app_id` (app cliente) |
   | `FIREBASE_APP_ID_GESTAO` | `client[0].client_info.mobilesdk_app_id` (app gestão) |
   | `FIREBASE_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |
4. Firebase → ⚙️ *Configurações do projeto → Contas de serviço* → **Gerar nova chave privada** (JSON).
   No servidor, no `.env` (nunca no repositório):
   `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64=` + saída de `base64 -w0 arquivo.json`, e reinicie (`docker compose up -d`).
5. Faça qualquer push na `main` (ou rode os workflows *Play Store* / *App (APK)*) para os apps saírem com o push.

iPhone: exige chave APNs da Apple (conta de desenvolvedor) — ainda não configurado.

## Como a fila funciona

Os eventos (novo agendamento, cancelamento, remarcação, confirmação, aceite do salão, promoções) entram numa
fila no banco (`push_outbox`) na mesma transação do fato. Um worker (`app.push.worker-ms`, padrão 10 s) envia
pelo FCM e tenta de novo com espera crescente (1 min, 5 min, 30 min, 2 h; até 5 tentativas). O app confirma o
recebimento em `/api/push/ack` (estados PENDING → SENT → RECEIVED; DEAD/EXPIRED se não chegou em 24 h).
Token inválido remove o aparelho. O salão só recebe os avisos do próprio profissional quando o acesso está ligado
a um profissional; donos recebem tudo. Sem Firebase configurado nada é enfileirado e os apps seguem
consultando em segundo plano (gestão a cada 15 min, cliente a cada 30 min; com push, 1 h e 3 h só como reserva).
