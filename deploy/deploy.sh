#!/usr/bin/env bash
# Roda no servidor (chamado pelo GitHub Actions): baixa as imagens novas e reinicia.
# Uso: API_IMAGE=... WEB_IMAGE=... bash /opt/salao-max/deploy.sh
set -euo pipefail
trap '' HUP

APP_DIR="${APP_DIR:-/opt/salao-max}"
cd "$APP_DIR"

if [[ ! -f .env ]]; then
  echo "ERRO: ${APP_DIR}/.env ausente (modelo: deploy/.env.production.example)"
  exit 1
fi

export COMPOSE_FILE=docker-compose.prod.yml
export COMPOSE_PARALLEL_LIMIT=1

echo "==> Pull das imagens"
docker compose pull api web

echo "==> Banco"
docker compose up -d db

echo "==> API, site e nginx"
docker compose up -d --remove-orphans

echo "==> Aguardando a API"
for i in $(seq 1 40); do
  if docker compose exec -T nginx wget -qO- http://api:8080/actuator/health 2>/dev/null | grep -q '"UP"'; then
    echo "API no ar."
    break
  fi
  if [[ "$i" -eq 40 ]]; then
    echo "API não respondeu em 200s. Últimos logs:"
    docker compose logs --tail=80 api
    exit 1
  fi
  sleep 5
done

docker image prune -f >/dev/null
docker ps --filter name=salao-max --format 'table {{.Names}}\t{{.Status}}'
echo "Deploy concluído em $(date -u +'%Y-%m-%dT%H:%M:%SZ')."
