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

## Alterações visuais: ver antes de entregar
- **Toda mudança de tela (app ou site) tem de ser vista renderizada antes de dizer que está pronta.** Teste que passa não prova
  que ficou bonito nem legível. Gere a imagem, abra com a ferramenta de leitura de imagens e só então avalie.
- App Flutter: `mobile/gestao/test/support/screenshot.dart` renderiza um widget/tela com as fontes e os ícones reais e salva um PNG
  (veja os exemplos em `mobile/gestao/test/shots/`; rode com `SHOTS=1 flutter test test/shots`). Teste em tela pequena (360 dp) e com
  fonte grande, que é onde costuma quebrar.
- Site: capture com Playwright (Chromium já instalado), em largura de celular (390 px) e de computador.
- Se o resultado estiver feio, melhore e confira de novo. Se uma biblioteca (animação, ícones, componentes) deixar a tela claramente
  melhor, use-a. Diga na resposta o que foi visto e o que a imagem não consegue mostrar.

## Pendências: nada de issue (o repositório é público)
- **Não abra issues nem comente pendências no GitHub**: o repositório é público. Também não escreva pendências, planos internos,
  dados de clientes, preços combinados ou detalhes do servidor em arquivos versionados além do que o código precisa.
- Pendências (o que ficou para depois, o que o usuário precisa fazer, defeito visto e não corrigido, decisão em aberto, teste que não
  deu para fazer) vão **na resposta ao usuário**, numa lista curta no final, para ele decidir.
