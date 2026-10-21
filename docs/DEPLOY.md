# Deploy e CI/CD — Salão Max

Produção: **https://salaomax.focodev.com.br** (site, painel e API em `/api`), servidor Hetzner,
exposto pelo túnel Cloudflare `gerenciamento-estoque`.

## Fluxo

```
PR            → CI: testes da API (Postgres), typecheck/build do site, analyze/testes dos apps
push na main  → Deploy (backend/ frontend/ deploy/): testes → imagens no GHCR → servidor faz pull e reinicia
              → App (mobile/): APK do canal "direct" de cada app → publicado na API → apps avisam a atualização
```

As imagens são buildadas no GitHub (`ghcr.io/agsterr/salao-max-api` e `salao-max-web`) porque a VPS
tem pouca RAM livre; o servidor só faz `docker compose pull`. Os containers têm limite de memória
(API com `-Xmx256m`).

## Servidor (`/opt/salao-max`)

| Arquivo | Origem |
|---|---|
| `docker-compose.prod.yml`, `nginx.conf`, `deploy.sh` | copiados pelo workflow a cada deploy (fonte: `deploy/`) |
| `.env` | só no servidor (modelo: `deploy/.env.production.example`) |

- Porta local: `127.0.0.1:8089` → nginx → `/api/*` e `/actuator/health` para a API, resto para o Next.
- Deploy manual: `ssh hetzner "cd /opt/salao-max && bash deploy.sh"`
- Logs: `ssh hetzner "cd /opt/salao-max && docker compose -f docker-compose.prod.yml logs -f api"`
- Senha do super-admin: `ssh hetzner "grep PLATFORM_ADMIN /opt/salao-max/.env"`

## Cloudflare

`deploy/cloudflare-hostname.sh` adiciona o hostname no túnel (preservando os outros) e cria o CNAME.
O token do servidor não tem *Zone Read*; nesse caso crie o DNS no painel uma vez:

| Nome | Tipo | Destino | Proxy |
|---|---|---|---|
| `salaomax` | CNAME | `4fe3f6e0-d2ec-4bca-8459-e66f81d95494.cfargotunnel.com` | Ativado |

ou rode com `CLOUDFLARE_ZONE_ID=<id da URL da zona> bash /opt/salao-max/cloudflare-hostname.sh`.

## Backup do banco

O serviço `backup` (em `deploy/docker-compose.prod.yml`) faz um `pg_dump` ao subir e depois a cada 24 h,
guardando os últimos `BACKUP_KEEP_DAYS` (padrão 14) no volume `db_backups`. Ver o log:
`docker logs salao-max-backup`.

- **Só neste servidor** protege de erro humano ou migração ruim, mas **não** de perder o servidor.
- **Cópia fora do servidor (recomendado):** crie um bucket **privado** no Cloudflare R2 (ex.: `salao-max-backup`,
  sem acesso público — nunca use o bucket de fotos, que é público), dê ao token "Object Read & Write" nele e
  coloque `BACKUP_BUCKET=salao-max-backup` no `.env` do servidor (usa as mesmas `R2_*` das fotos). Faça `docker compose up -d`.
- **Restaurar** (num banco vazio, com a API parada):

```bash
cd /opt/salao-max && export COMPOSE_FILE=docker-compose.prod.yml
docker compose stop api
docker run --rm -v salao-max_db_backups:/b alpine ls /b            # escolha o arquivo
docker run --rm -v salao-max_db_backups:/b alpine cat /b/salao-AAAA-MM-DD-HHMM.sql.gz \
  | gunzip | docker compose exec -T db psql -U salao salao
docker compose start api
```

Teste a restauração de vez em quando num banco à parte: um backup que nunca foi restaurado não é garantia.

## Secrets do GitHub

| Secret | Uso |
|---|---|
| `HETZNER_HOST`, `HETZNER_USER`, `HETZNER_SSH_KEY` | SSH do deploy |
| `APP_RELEASE_DEPLOY_TOKEN` | publicar APK na API (mesmo valor do `.env` do servidor) |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | assinatura do APK |

> **Guarde o keystore** (`upload-keystore.jks`) em lugar seguro. Sem ele não dá para publicar
> atualização que instale por cima das versões já instaladas.

## App fora da loja × Play Store

- **Canal `direct`** (APK no site): o workflow *App (APK fora da loja)* publica a cada push em
  `mobile/`. Para forçar atualização (bloqueia o app até atualizar): *Actions → App (APK fora da loja)
  → Run workflow → Atualização obrigatória*, ou ligue o *forceUpdate* da versão no painel `/plataforma`.
- **Canal `play`**: sem auto-update nem permissão de instalar pacotes (exigência da Play); a loja
  atualiza. Gere o `.aab` com `flutter build appbundle --release --flavor play --dart-define=DISTRIBUTION=play ...`.
- Download direto do APK mais recente: `https://salaomax.focodev.com.br/api/app/download/latest?app=gestao`
  (ou `app=cliente`).
