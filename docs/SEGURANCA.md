# Segurança contra robôs e excesso de requisições

O Salão Max usa **três camadas**. A primeira e a terceira ficam na Cloudflare (painel dela); a do meio é do código.

## 1. Cloudflare (na frente do site, grátis)
O servidor só é acessado pelo túnel da Cloudflare, e ela já segura ataques de rede pesados. Ligue também:

1. **Bot Fight Mode**: Segurança → Bots → *Bot Fight Mode* ligado.
2. **Regra de limite de requisições** (o plano grátis tem 1 regra): Segurança → WAF → *Rate limiting rules*.
   - Quando a URL contém `/api/` e o método é `POST`,
   - contar por IP, **100 requisições por 10 segundos**, ação **Bloquear** por 10 segundos (no plano grátis é a única duração permitida; planos pagos permitem mais).
   - Não aplique a `/api/asaas/webhook` (é o Asaas falando com o servidor).
3. Em ataque forte, use **Modo "Estou sob ataque"** (Segurança → Visão geral). Ele pede uma verificação rápida a cada visitante.

## 2. Código (limites e captcha)
- `AbuseLimiter` (limites em memória, 429 quando passa):
  - login: 60 por IP e 10 por e-mail a cada 10 min;
  - cadastro de salão: 5 por IP por hora;
  - cadastro de representante: 10 por IP a cada 10 min e 5 por IP por hora;
  - agendamento público: 60 por IP e 10 por telefone a cada 10 min;
  - "meus agendamentos" e recuperar senha: `LookupRateLimiter`.
- **Captcha Cloudflare Turnstile** nos cadastros de salão e de representante. Fica **desligado** até existirem as chaves.

### Ligar o Turnstile (uma vez)
1. Cloudflare → *Turnstile* → **Add widget**: nome `Salão Max`, domínio `salaomax.focodev.com.br`, modo **Managed**.
2. A Cloudflare mostra a **Site Key** (pública) e a **Secret Key** (segredo).
3. No servidor, em `/opt/salao-max/.env`:
   ```
   TURNSTILE_SITE_KEY=<site key>
   TURNSTILE_SECRET=<secret key>
   ```
   (a secret nunca vai para o git; use o script "cole e tecle Enter" do projeto).
4. Recrie a API: `cd /opt/salao-max && COMPOSE_FILE=docker-compose.prod.yml API_IMAGE=<imagem atual> docker compose up -d api`.
5. Confira: `curl https://salaomax.focodev.com.br/api/public/config` deve mostrar a `turnstileSiteKey`.

Para testes, a Cloudflare tem chaves que sempre passam: site key `1x00000000000000000000AA` e secret `1x0000000000000000000000000000000AA`.

## 3. Boas práticas
- O limite do código vale por IP; atrás da Cloudflare o IP vem de `CF-Connecting-IP`.
- O app móvel não usa captcha (login e agendamento seguem só com os limites).
