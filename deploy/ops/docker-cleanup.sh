#!/usr/bin/env bash
# Limpeza do disco do servidor (roda toda semana pelo cron; veja deploy/ops/README.md).
# Seguro para os outros apps do servidor:
#  - cache de build: só o que tem mais de 7 dias (nunca apaga imagem de nenhum app);
#  - imagens "soltas" (sem nome, sem uso);
#  - imagens do Salão Max com tag de commit: mantém as KEEP mais recentes de cada uma (padrão 4) e as
#    tags rollback-*; o Docker recusa apagar imagem de container existente, então nada em uso é perdido.
# Nunca mexe em volumes (bancos, fotos, backups).
# Uso: bash docker-cleanup.sh [--dry-run]
set -euo pipefail

KEEP="${KEEP:-4}"
DRY=false
[[ "${1:-}" == "--dry-run" ]] && DRY=true

echo "==> Disco antes: $(df -h / | awk 'NR==2 {print $3 " usados, " $4 " livres (" $5 ")"}')"

for repo in ghcr.io/agsterr/salao-max-api ghcr.io/agsterr/salao-max-web; do
  # tags de commit (40 hex), da mais nova para a mais antiga; pula as KEEP primeiras
  mapfile -t old < <(docker images "$repo" --format '{{.CreatedAt}}|{{.Tag}}' | sort -r \
    | cut -d'|' -f2 | grep -E '^[0-9a-f]{40}$' | tail -n +$((KEEP + 1)) || true)
  for tag in "${old[@]}"; do
    if $DRY; then
      echo "apagaria $repo:$tag"
    else
      docker rmi "$repo:$tag" >/dev/null 2>&1 && echo "apagada $repo:$tag" || echo "mantida (em uso) $repo:$tag"
    fi
  done
done

if $DRY; then
  echo "(simulação) cache de build reclamável:"
  docker builder du 2>/dev/null | tail -2
else
  docker image prune -f >/dev/null
  docker builder prune -f --filter "until=168h" >/dev/null
fi

echo "==> Disco depois: $(df -h / | awk 'NR==2 {print $3 " usados, " $4 " livres (" $5 ")"}')"
