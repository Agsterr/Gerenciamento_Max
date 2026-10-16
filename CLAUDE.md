# Salão Max — instruções para agentes

## Publicar (deploy)
- **Não é preciso acesso ao servidor.** Push na `main` publica sozinho pelo GitHub Actions:
  `backend/`, `frontend/`, `deploy/` → `.github/workflows/deploy.yml` (servidor Hetzner);
  `mobile/` → `.github/workflows/mobile-release.yml` (APK fora da loja).
- Quando terminar uma mudança: commit e **push direto na `main`** (sem PR), a não ser que o usuário peça PR.
- Sessão na nuvem que só consegue enviar para o próprio branch (`ccr-*`): basta dar push nele.
  `.github/workflows/cloud-to-main.yml` mescla na `main` e dispara o deploy. Antes, rode `git pull origin main`
  para evitar conflito; se houver conflito o workflow falha e nada é publicado.
- Nunca grave senhas, tokens ou chaves no repositório: ficam nos *secrets* do GitHub (veja `docs/DEPLOY.md`).

## Projeto
- `backend/` Spring Boot, `frontend/` Next.js (painel do salão e páginas públicas de agendamento `/s/<slug>`),
  `mobile/` apps Flutter (`gestao`, `cliente`, pacote comum `core`) — veja `mobile/README.md`.
- Textos, commits e PRs em português.
