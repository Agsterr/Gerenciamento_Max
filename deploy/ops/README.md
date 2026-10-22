# Rotinas do servidor (Hetzner)

Scripts instalados em `/opt/salao-max/ops/` e agendados pelo `crontab` do root.

| Script | Quando | O que faz |
|---|---|---|
| `backup-offsite.sh` | todo dia 06:30 UTC (03:30 em Brasília) | `pg_dumpall` de **todos** os bancos Postgres do servidor e envio para o bucket privado `focodev-backups` do Cloudflare R2, em `<container>/<AAAA-MM-DD_HHMM>.sql.gz`. Confere o tamanho no R2 depois de enviar. |
| `docker-cleanup.sh` | domingo 04:00 | Apaga cache de build com mais de 7 dias, imagens soltas e imagens antigas do Salão Max (mantém as 4 mais recentes e as `rollback-*`). Não mexe em volumes nem em imagens de outros apps. |
| `setup-r2-backup.sh` | uma vez | Pergunta endpoint, bucket e chaves do R2 e grava em `/root/.secrets/r2-backup.env` (chmod 600). As chaves nunca vão para o git. |

Logs: `/var/log/backup-offsite.log` e `/var/log/docker-cleanup.log`.

## Retenção

O script não apaga nada: o bucket tem a regra de ciclo de vida `apagar-apos-30-dias`. Para guardar por mais tempo, mude a regra
em R2 → `focodev-backups` → Configurações → Regras do ciclo de vida.

## Credencial do R2

Token de API de conta com **Leitura/gravação para objeto**, só no bucket `focodev-backups`. Para trocar, crie outro token no painel
do Cloudflare e rode `bash /opt/salao-max/ops/setup-r2-backup.sh`.

## Restaurar um backup

1. Baixe o arquivo (use as variáveis de `/root/.secrets/r2-backup.env`):

   ```bash
   source /root/.secrets/r2-backup.env
   curl -sS --aws-sigv4 "aws:amz:auto:s3" --user "$R2_ACCESS_KEY_ID:$R2_SECRET_ACCESS_KEY" \
     "$R2_ENDPOINT/$R2_BUCKET/salao-max-db/2026-10-22_2322.sql.gz" -o /tmp/dump.sql.gz
   ```

2. **Teste primeiro** em um Postgres temporário, sem tocar na produção:

   ```bash
   docker run -d --name restore-test -e POSTGRES_PASSWORD=teste postgres:16-alpine
   zcat /tmp/dump.sql.gz | docker exec -i restore-test psql -U postgres -q
   docker exec restore-test psql -U postgres -d salao -c '\dt'
   docker rm -f restore-test
   ```

3. Para restaurar na produção (banco perdido ou corrompido): pare a API, recrie o container do banco com o volume vazio e rode o
   mesmo `zcat ... | docker exec -i <container-do-banco> psql -U <usuario>`, depois suba a API.

Última restauração testada: 22/10/2026 (banco do Salão Max idêntico ao de produção: 12 salões, 78 agendamentos, mesmas migrações).

## Não coberto por este backup

Arquivos fora do Postgres: volume `salon_media` (só se o R2 de fotos não estiver ligado), `marketing-minio`, `.env` de cada app e
certificados. Os `.env` ficam só no servidor: guarde uma cópia em um gerenciador de senhas.
