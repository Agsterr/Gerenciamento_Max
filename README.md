# Salão Max — gestão de salão de beleza

Sistema **multi-tenant** para salões de beleza: cada salão se cadastra, gerencia a própria operação
e ganha uma página pública para os clientes agendarem pelo celular.

| | |
|---|---|
| **Backend** | Java 21 · Spring Boot 3.5 · Spring Security (JWT) · JPA/Hibernate · Flyway · PostgreSQL |
| **Frontend** | Next.js 16 (App Router) · React 19 · TypeScript · Tailwind CSS 4 |
| **Apps** | Flutter: **Salão Max** (cliente) e **Salão Max Gestão** (salão) — veja [mobile/](mobile/README.md) |

## Funcionalidades

**Versão do salão (`/painel`)**
- **Agenda do dia** por profissional: agendar, confirmar, iniciar, finalizar, cancelar, marcar falta. Link direto para o WhatsApp do cliente.
- **Agendamento manual**: além da grade de horários livres, o salão pode marcar em qualquer horário, com duração própria, e fazer **encaixe** (ignora conflito e expediente).
- **Horários livres calculados** a partir do expediente do salão e da agenda de cada profissional — sem encaixe duplicado (trava pessimista no profissional).
- **Controle de tempo**: duração prevista do serviço × tempo real (iniciar → finalizar).
- **Clientes** com busca por nome/telefone, observações e histórico (total gasto).
- **Serviços** com duração, preço, custo de material e margem.
- **Profissionais** com % de comissão (calculada no fechamento do atendimento).
- **Produtos e estoque**: entrada, venda, uso em atendimento e perda, com alerta de estoque mínimo.
- **Precificação**: para cada serviço calcula o custo direto (material + parte do custo fixo pelo tempo de cadeira, usando o tempo real quando é maior), o **preço mínimo** (lucro zero) e o **preço sugerido** para a margem desejada, já descontando comissão e taxa de cartão. Mostra quem dá prejuízo, simula qualquer preço e aplica o sugerido com um toque.
- **Financeiro**: receita (serviços + produtos), custos (comissões, material, produtos, despesas), lucro, ticket médio, ranking por profissional/serviço e lançamento de despesas.
- **Equipe**: perfis *Dono* (tudo) e *Funcionário* (sem financeiro/configurações).

**Versão do cliente (`/s/{slug-do-salao}`)**
- Escolhe serviço → profissional (ou "sem preferência") → dia e horário → nome e WhatsApp. Sem cadastro, sem senha.
- Recebe um link para consultar ou cancelar (até 2h antes).

**Apps para Android e iOS (`mobile/`)**
- Mesmas funções do site em apps nativos Flutter, já configurados para os requisitos da Google Play e da
  App Store (target SDK 36, privacy manifest, exclusão de conta, HTTPS). Checklist em [mobile/STORES.md](mobile/STORES.md).

**Páginas legais** (exigidas pelas lojas): `/privacidade`, `/termos` e `/excluir-conta`.

## Rodando

### Com Docker
```bash
docker compose up --build
```
Frontend em http://localhost:3000 · API em http://localhost:8080.

### Local (desenvolvimento)
Pré-requisitos: Java 21, Maven, Node 22 e PostgreSQL.

```bash
# banco
createdb salao   # usuário/senha padrão: salao/salao (veja application.yml)

# API
cd backend && mvn spring-boot:run

# Web
cd frontend && cp .env.example .env.local && npm install && npm run dev
```

Acesse http://localhost:3000, clique em **Criar meu salão**, cadastre profissionais e serviços e
compartilhe o link de agendamento que aparece em **Configurações**.

### Testes
Os testes de integração rodam contra um PostgreSQL real (banco `salao_test`):
```bash
createdb salao_test
cd backend && mvn test        # TEST_DB_URL, DB_USER e DB_PASSWORD são configuráveis
cd frontend && npm run typecheck && npm run build
```

## Arquitetura

```
backend/src/main/java/com/max/salao
├── shared/        TenantContext, resolver do Hibernate, erros (ProblemDetail)
├── security/      JWT (HS256), filtro de tenant, regras de acesso
├── auth/          cadastro do salão, login, usuários
├── salon/         dados e expediente do salão (o tenant)
├── professional/  catalog/  customer/  product/  expense/
├── appointment/   agenda, disponibilidade, ciclo de vida do atendimento
├── booking/       API pública de agendamento (tenant pelo slug)
└── report/        resumo financeiro e operacional
```

Organização **por funcionalidade**, sem camadas desnecessárias: CRUDs simples vão do controller ao
repositório; regras de negócio ficam em services (`AppointmentService`, `AvailabilityService`,
`ProductService`, `ReportService`) e no próprio domínio (`Appointment.finish()`, `cancel()`...).

### Multi-tenant
- Banco compartilhado, **coluna `tenant_id`** em todas as tabelas de negócio.
- Entidades estendem `TenantEntity` (`@TenantId` do Hibernate): o Hibernate **filtra e preenche o
  tenant automaticamente** em todas as consultas — não dá para "esquecer o where".
- O tenant da requisição vem do claim `tenant` do JWT (painel) ou do `slug` na URL (páginas públicas).
- Há teste garantindo que um salão não enxerga dados de outro.

### Principais endpoints
| Método | Rota | Quem |
|---|---|---|
| POST | `/api/auth/register`, `/api/auth/login` | público |
| GET · POST | `/api/me` · `/api/me/delete` (exclusão de conta) | painel |
| GET/POST/PUT | `/api/customers`, `/api/products`, `/api/services`, `/api/professionals` | painel |
| GET | `/api/appointments?from=&to=` · `/api/appointments/availability` | painel |
| POST | `/api/appointments` (`durationMinutes`, `force` para encaixe) · `/{id}/confirm` · `/start` · `/finish` · `/cancel` · `/no-show` | painel |
| POST | `/api/products/{id}/movements` | painel |
| GET | `/api/reports/summary?from=&to=` · CRUD `/api/expenses` | dono |
| GET · PUT | `/api/pricing` · `/api/pricing/settings` (precificação) | dono |
| GET | `/api/public/salons?q=` (busca) · `/api/public/salons/{slug}` · `/availability` | cliente |
| POST/GET | `/api/public/salons/{slug}/bookings[/{token}[/cancel]]` | cliente |

## Variáveis de ambiente (API)
| Variável | Padrão |
|---|---|
| `DB_URL` / `DB_USER` / `DB_PASSWORD` | `jdbc:postgresql://localhost:5432/salao` / `salao` / `salao` |
| `JWT_SECRET` | segredo de desenvolvimento — **troque em produção** (≥ 32 caracteres) |
| `CORS_ORIGINS` | `http://localhost:3000` |
| `APP_TIMEZONE` | `America/Sao_Paulo` |

Site: `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_LEGAL_COMPANY` e `NEXT_PUBLIC_LEGAL_EMAIL` (aparecem na política de privacidade).

## Próximos passos sugeridos
- Lembrete automático por WhatsApp/e-mail na véspera.
- Horário individual e folgas por profissional; serviços por profissional.
- Formas de pagamento e fechamento de caixa.
- Limite de requisições na API pública.
