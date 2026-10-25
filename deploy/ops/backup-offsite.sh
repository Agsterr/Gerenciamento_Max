#!/usr/bin/env bash
# Backup diário de TODOS os bancos Postgres do servidor para um bucket privado do Cloudflare R2
# (fora da Hetzner: se o disco ou o servidor se perderem, os dados continuam no R2).
# - Um pg_dumpall por container Postgres, comprimido (restaura tudo: bancos, papéis e dados).
# - Envio com o próprio curl (assinatura SigV4): não instala nada no servidor.
# - Retenção: regra de ciclo de vida do bucket (apaga com 30 dias); o script não apaga nada.
# - Credenciais em /root/.secrets/r2-backup.env (chmod 600), criado por ops/setup-r2-backup.sh.
# Uso: bash backup-offsite.sh            (cron diário)
#      bash backup-offsite.sh --test     (envia só um arquivo de teste e confere)
set -euo pipefail

CONF="${R2_BACKUP_ENV:-/root/.secrets/r2-backup.env}"
[[ -r "$CONF" ]] || { echo "ERRO: $CONF ausente (rode ops/setup-r2-backup.sh)"; exit 1; }
# shellcheck disable=SC1090
source "$CONF"
: "${R2_ENDPOINT:?}" "${R2_BUCKET:?}" "${R2_ACCESS_KEY_ID:?}" "${R2_SECRET_ACCESS_KEY:?}"

HOST_NAME="$(hostname -s)"
STAMP="$(date -u +%Y-%m-%d_%H%M)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

upload() { # arquivo chave
  local code
  code=$(curl -sS -o "$TMP/resp" -w '%{http_code}' -m 300 -X PUT -T "$1" \
    --aws-sigv4 "aws:amz:auto:s3" --user "${R2_ACCESS_KEY_ID}:${R2_SECRET_ACCESS_KEY}" \
    "${R2_ENDPOINT%/}/${R2_BUCKET}/$2")
  if [[ "$code" != "200" ]]; then
    echo "FALHA ao enviar $2: HTTP $code $(head -c 300 "$TMP/resp")"; return 1
  fi
}

size_remote() { # chave -> tamanho em bytes no R2
  curl -sSI -m 60 --aws-sigv4 "aws:amz:auto:s3" --user "${R2_ACCESS_KEY_ID}:${R2_SECRET_ACCESS_KEY}" \
    "${R2_ENDPOINT%/}/${R2_BUCKET}/$1" | awk 'tolower($1)=="content-length:" {print $2}' | tr -d '\r'
}

if [[ "${1:-}" == "--test" ]]; then
  echo "teste de backup $(date -u)" > "$TMP/teste.txt"
  upload "$TMP/teste.txt" "_teste/${HOST_NAME}-${STAMP}.txt"
  echo "OK: arquivo de teste enviado ($(size_remote "_teste/${HOST_NAME}-${STAMP}.txt") bytes no R2)"
  exit 0
fi

fail=0
# containers Postgres (inclui pgvector); o "-backup" do Salão Max só usa a imagem
mapfile -t DBS < <(docker ps --format '{{.Names}} {{.Image}}' | awk '$2 ~ /postgres|pgvector/ && $1 !~ /-backup$/ {print $1}')
echo "==> ${#DBS[@]} bancos: ${DBS[*]}"
for c in "${DBS[@]}"; do
  file="$TMP/${c}.sql.gz"
  if ! docker exec "$c" sh -c 'pg_dumpall -U "${POSTGRES_USER:-postgres}"' | gzip -6 > "$file"; then
    echo "FALHA no dump de $c"; fail=1; continue
  fi
  bytes=$(stat -c %s "$file")
  # dump vazio/minúsculo = algo errado (não manda lixo por cima de um backup bom)
  if (( bytes < 500 )); then echo "FALHA: dump de $c com $bytes bytes"; fail=1; continue; fi
  key="${c}/${STAMP}.sql.gz"
  if upload "$file" "$key" && [[ "$(size_remote "$key")" == "$bytes" ]]; then
    echo "ok: $key ($bytes bytes)"
  else
    echo "FALHA: envio/conferência de $key"; fail=1
  fi
done

(( fail == 0 )) && echo "==> Backup completo em $(date -u +%FT%TZ)" || { echo "==> Backup COM FALHAS"; exit 1; }
