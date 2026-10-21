# Roteiro de verificação — Resend, Firebase e cancelamento (Salão Max)

Para o agente local (com acesso SSH ao servidor `ssh hetzner`). **Só leitura**, exceto o item 6, que dispara um e-mail de teste.
Regras: nunca imprimir chaves inteiras (só tamanho ou os primeiros caracteres) e não alterar o `.env` sem pedir ao usuário.
Servidor: `/opt/salao-max` (compose: `docker-compose.prod.yml`, API: container `salao-max-api`, site: https://salaomax.focodev.com.br).

## 1. Containers e API no ar
```bash
ssh hetzner "docker ps --format '{{.Names}}  {{.Status}}' | grep salao-max"
ssh hetzner "docker logs --tail 60 salao-max-api | grep -i -E 'Started SalaoApplication|ERROR|Exception'"
```
Esperado: `salao-max-api`, `-web`, `-db`, `-nginx`, `-backup` como `Up`; linha `Started SalaoApplication`; nenhum ERROR.
O aviso do Flyway "versão 19 mais nova que a última disponível (9)" é ruído (as 19 migrações são validadas).

## 2. Variáveis do `.env` (sem mostrar segredos)
```bash
# Firebase: presença + tamanho (esperado ~3200) + JSON válido do projeto certo
ssh hetzner "grep '^FIREBASE_SERVICE_ACCOUNT_JSON_BASE64=' /opt/salao-max/.env | wc -c"
ssh hetzner "grep '^FIREBASE_SERVICE_ACCOUNT_JSON_BASE64=' /opt/salao-max/.env | cut -d= -f2- | base64 -d | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[\"project_id\"], d[\"client_email\"])'"
# Resend: só o prefixo (esperado: re_) e o remetente
ssh hetzner "grep '^RESEND_API_KEY=' /opt/salao-max/.env | cut -c1-18"
ssh hetzner "grep '^MAIL_FROM=' /opt/salao-max/.env"
```
Esperado: Firebase imprime `salaomax-13177` e um e-mail `firebase-adminsdk-...@salaomax-13177.iam.gserviceaccount.com`.
Resend imprime `RESEND_API_KEY=re_` e o `MAIL_FROM` deve ser de `@salaomax.focodev.com.br`.
Confirme que o container recebeu as variáveis (só nomes/tamanhos):
```bash
ssh hetzner "docker exec salao-max-api sh -c 'for v in RESEND_API_KEY FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 MAIL_FROM; do eval x=\$$v; echo \$v tamanho=\${#x}; done'"
```
Esperado: tamanhos > 0. Se o `.env` mudou depois do último `docker compose up -d`, a API precisa ser recriada.

## 3. Resend: domínio e DNS
```bash
dig +short CNAME send.salaomax.focodev.com.br        # send.forge.rmta.net.
dig +short CNAME rsend.salaomax.focodev.com.br       # rsend-sae1.forge.rmta.net.
dig +short TXT resend._domainkey.salaomax.focodev.com.br   # começa com "p=MIGf..."
```
Depois abrir https://resend.com/domains e conferir que `salaomax.focodev.com.br` está **Verified** (não "Not Started"/"Pending").
Se não estiver: clicar em "Verificar registros DNS" e esperar a propagação. Os 3 registros foram criados no Cloudflare (zona focodev.com.br) com proxy desligado ("Somente DNS").

## 4. Cancelamento pelo cliente (liberar vaga)
```bash
ssh hetzner "docker exec salao-max-db psql -U salao salao -c \"select version, success from flyway_schema_history order by installed_rank desc limit 3\""
ssh hetzner "docker exec salao-max-db psql -U salao salao -c \"select column_name from information_schema.columns where (table_name='salon' and column_name='release_slot_on_cancel') or (table_name='appointment' and column_name='slot_held')\""
```
Esperado: versão 19 com `success = t` e as duas colunas listadas.
Teste funcional (no painel/app de gestão, Configurações): ligar/desligar "Liberar a vaga quando o cliente cancelar", cancelar um agendamento pelo link do cliente e conferir:
- ligado: o horário volta a aparecer livre na página `/s/<slug>`;
- desligado: o horário continua indisponível e o sino do painel recebe "Agendamento cancelado pelo cliente".

## 5. Firebase / push
- Segredos no GitHub (só nomes): `gh secret list --repo Agsterr/Gerenciamento_Max | grep FIREBASE` → `FIREBASE_API_KEY`, `FIREBASE_APP_ID_CLIENTE`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`.
- Builds dos apps com os secrets: `gh run list --repo Agsterr/Gerenciamento_Max --limit 6` → os workflows *Play Store* e *App (APK fora da loja)* disparados em 21/10 (23:10 UTC) concluídos com sucesso.
- Logs do servidor: `ssh hetzner "docker logs --since 1h salao-max-api | grep -i -E 'fcm|push|firebase'"`. Erros conhecidos: `FCM respondeu 401/403` (conta de serviço sem permissão), `Falha ao enviar push`.
- Teste real: instalar o app do cliente **novo** (compilado depois dos secrets), abrir um salão (o celular se registra em `POST /api/public/salons/<slug>/presence`), criar uma promoção no app de gestão com "Avisar os clientes no celular" ligado e esperar até 5 minutos. No log deve aparecer `Push de promoções: N enviados`.
  Confirmar o registro do celular: `ssh hetzner "docker exec salao-max-db psql -U salao salao -c 'select count(*) from push_device'"` (nome da tabela pode variar; ver `V18__push_firebase.sql`).

## 6. E-mail de recuperar senha (único teste que envia algo)
Usar um e-mail de um usuário real do painel, que o usuário controle:
```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://salaomax.focodev.com.br/api/auth/forgot-password -H 'Content-Type: application/json' -d '{"email":"EMAIL_DO_USUARIO"}'
ssh hetzner "docker logs --since 5m salao-max-api | grep -i -E 'e-mail|resend|mail'"
```
Esperado: HTTP 2xx, o e-mail chega (confira a caixa e o spam) e **não** aparece `E-mail NÃO enviado (RESEND_API_KEY ausente)` nem `Resend respondeu 4xx`.
Erros comuns: `403 domain is not verified` (domínio não verificado ou `MAIL_FROM` de outro domínio), `401` (chave errada). Também há a página `/esqueci-senha` no site.

## 7. Limpeza (só depois de tudo OK, perguntando ao usuário)
- `ssh hetzner "ls -la /opt/salao-max/.env*"`: `.env.bak` guarda uma cópia anterior do `.env` com segredos; apagar quando não for mais necessário.
- Chaves no computador: `C:\Users\agste_765q4js\.android-keys\salao-max\` (firebase-adminsdk.json, google-services.json). Não devem estar em Downloads nem no repositório.
- Apagar este arquivo (`roteiro-verificacao.md`) se não quiser versioná-lo.

## Relatório esperado
Uma lista com ✅/❌ para cada item 1–6, com o trecho de log relevante em caso de falha (sem segredos).
