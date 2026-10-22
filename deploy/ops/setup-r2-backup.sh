#!/usr/bin/env bash
# Guarda as chaves do R2 de backup no servidor. RODE VOCÊ, no servidor: as chaves são digitadas aqui
# (não aparecem na tela) e vão só para /root/.secrets/r2-backup.env (chmod 600), nunca para o git.
# Uso: bash /opt/salao-max/ops/setup-r2-backup.sh
set -euo pipefail

CONF=/root/.secrets/r2-backup.env
mkdir -p /root/.secrets && chmod 700 /root/.secrets

read -r -p "Endpoint S3 do R2 (https://<ACCOUNT_ID>.r2.cloudflarestorage.com): " endpoint
read -r -p "Nome do bucket [focodev-backups]: " bucket
bucket="${bucket:-focodev-backups}"
read -r -p "Access Key ID: " key_id
read -r -s -p "Secret Access Key (não aparece): " secret
echo

umask 077
cat > "$CONF" <<EOF
R2_ENDPOINT=${endpoint%/}
R2_BUCKET=${bucket}
R2_ACCESS_KEY_ID=${key_id}
R2_SECRET_ACCESS_KEY=${secret}
EOF
chmod 600 "$CONF"
echo "Salvo em $CONF"

echo "==> Testando o envio..."
bash "$(dirname "$0")/backup-offsite.sh" --test
