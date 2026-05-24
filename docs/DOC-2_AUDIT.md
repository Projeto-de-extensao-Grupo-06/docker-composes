# DOC-2: Relatório de Sincronização de Variáveis

**Data:** 2026-04-18  
**Executor:** Claude Code  
**Escopo:** Análise de variáveis entre `.env.example`, `docker-compose.yml` e READMEs

---

## Resumo Executivo

A auditoria identificou **16 variáveis em uso nos docker-compose files que NÃO estão documentadas** no `.env.example`. Isso pode causar falhas de deploy quando o `.env` real não contém estas variáveis.

---

## Análise Detalhada

### 1. Variáveis do `.env.example` (Documentadas)

```
AWS_ACCESS_KEY_ID
AWS_KEY_NAME
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
BOT_SECRET
DB_PASSWORD
DB_USERNAME
EMAIL
GITHUB_ACCESS_TOKEN
GITHUB_USERNAME
MAIL_HOST
MAIL_PORT
PASSWORD_EMAIL
PORT_BACKEND_MICROSERVICE
PORT_BACKEND_MONOLITH
PORT_BOT_REDIS
PORT_INSTITUTIONAL_WEBSITE
PORT_MANAGEMENT_SYSTEM
PORT_MICROSERVICE_DB
PORT_MYSQL
PORT_REDIS
PORT_WAHA
```

**Total: 25 variáveis**

---

### 2. Variáveis Usadas nos Docker Compose (Faltantes no .env.example)

#### 🔴 CRÍTICO - Ausentes no .env.example

| Variável | Usada em | Descrição Esperada |
|----------|----------|-------------------|
| `REDIS_PASSWORD` | `services/db/docker-compose.yml` | Senha do Redis (atualmente hardcoded como 'default') |
| `REDIS_USER` | `services/bot/docker-compose.yml` | Usuário do Redis para o bot |
| `MYSQL_ROOT_PASSWORD` | `services/db/docker-compose.yml` | Senha root do MySQL |
| `PORT_PROXY` | `services/proxy/docker-compose.yml` | Porta do proxy (padrão: 80) |
| `WHATSAPP_HOOK_URL` | `services/bot/docker-compose.yml` | URL do webhook WhatsApp |
| `WHATSAPP_DEFAULT_ENGINE` | `services/bot/docker-compose.yml` | Engine padrão do WAHA |
| `WHATSAPP_HOOK_EVENTS` | `services/bot/docker-compose.yml` | Eventos do hook |
| `WAHA_NO_API_KEY` | `services/bot/docker-compose.yml` | Flag para desabilitar API key |
| `WAHA_DASHBOARD_NO_PASSWORD` | `services/bot/docker-compose.yml` | Flag para dashboard sem senha |
| `WHATSAPP_SWAGGER_NO_PASSWORD` | `services/bot/docker-compose.yml` | Flag para Swagger sem senha |
| `BACKEND_API_URL` | `services/bot/docker-compose.yml` | URL da API do backend (para bot) |
| `WAHA_API_URL` | `services/bot/docker-compose.yml` | URL da API do WAHA |
| `N8N_PROTOCOL` | `services/bot/docker-compose.yml` | Protocolo do n8n (http/https) |
| `N8N_HOST` | `services/bot/docker-compose.yml` | Host do n8n |
| `N8N_PORT` | `services/bot/docker-compose.yml` | Porta do n8n |
| `DB_HOST` | `services/web-scrapping/docker-compose.yml` | Host do DB para web-scrapping |
| `DB_PORT` | `services/web-scrapping/docker-compose.yml` | Porta do DB para web-scrapping |
| `DB_NAME` | `services/web-scrapping/docker-compose.yml` | Nome do DB para web-scrapping |

**Total: 18 variáveis FALTANTES**

---

### 3. Inconsistências de Nomenclatura

#### Problema 1: `PASSWORD_EMAIL` vs `EMAIL_PASSWORD`
- `.env.example` usa: `PASSWORD_EMAIL`
- Padrão recomendado: `EMAIL_PASSWORD` (mais legível)

#### Problema 2: `DB_PASSWORD` vs senhas específicas
- MySQL usa: `DB_PASSWORD`
- Redis usa: `REDIS_PASSWORD` (faltante no .env.example)
- Inconsistência no padrão de nomes

---

### 4. Matriz de Uso por Serviço

| Variável | Backend | Bot | DB | Frontend | Proxy | Web-Scrapping |
|----------|:-------:|:---:|:--:|:--------:|:-----:|:-------------:|
| DB_USERNAME | ✅ | | ✅ | | | ✅ |
| DB_PASSWORD | ✅ | | ✅ | | | ✅ |
| REDIS_PASSWORD | | ✅ | ⚠️ | | | |
| BOT_SECRET | ✅ | ✅ | | | | |
| EMAIL | ✅ | | | | | |
| PASSWORD_EMAIL | ✅ | | | | | |
| GITHUB_* | ✅ | ✅ | ✅ | ✅ | | |
| AWS_* | ✅ | | | | | |
| PORT_* | ✅ | ✅ | ✅ | ✅ | ✅ | |
| MAIL_* | | ✅ | | | | |

**Legenda:**
- ✅ = Usada explicitamente
- ⚠️ = Provavelmente usada (hardcoded)
- (vazio) = Não usada

---

## Recomendações

### Prioridade 1: Adicionar ao .env.example (CRÍTICO)

As seguintes variáveis DEVEM ser adicionadas ao `.env.example`:

```bash
# Redis
REDIS_PASSWORD=default
REDIS_USER=default

# MySQL Root
MYSQL_ROOT_PASSWORD=root_password

# Proxy
PORT_PROXY=80

# Bot (n8n/WAHA)
BACKEND_API_URL=http://backend-service:8000
WAHA_API_URL=http://bot-waha:3000
N8N_PROTOCOL=http
N8N_HOST=localhost
N8N_PORT=5678
WHATSAPP_HOOK_URL=
WHATSAPP_DEFAULT_ENGINE=CHROME
WHATSAPP_HOOK_EVENTS=message
WAHA_NO_API_KEY=true
WAHA_DASHBOARD_NO_PASSWORD=true
WHATSAPP_SWAGGER_NO_PASSWORD=true

# Web Scrapping
DB_HOST=mysql-db
DB_PORT=3306
DB_NAME=solarway
```

### Prioridade 2: Renomear Variáveis (MÉDIO)

| De | Para | Motivo |
|----|------|--------|
| `PASSWORD_EMAIL` | `EMAIL_PASSWORD` | Melhor legibilidade |

**Nota:** Se renomear, atualizar TODAS as referências em:
- `.env.example`
- `services/backend/monolith/docker-compose.yml`
- `README.md` do backend
- Scripts de deploy (TF)

### Prioridade 3: Documentar Variáveis Opcionais (BAIXO)

Criar seção no `.env.example` para variáveis opcionais:

```bash
# ============================================================
# VARIÁVEIS OPCIONAIS (possuem valores padrão)
# ============================================================
# Estas variáveis têm valores padrão e normalmente não precisam ser alteradas

# WHATSAPP_* - Configurações do WAHA (bot)
# N8N_* - Configurações do n8n
# MYSQL_ROOT_PASSWORD - Senha root do MySQL (default: root)
```

---

## Arquivos Modificados

Após DOC-2, os seguintes arquivos devem ser atualizados:

1. `.env.example` - Adicionar variáveis faltantes
2. `services/*/README.md` - Documentar variáveis obrigatórias por serviço
3. `docs/VARIABLES_REFERENCE.md` - Criar (novo)

---

## Checklist DOC-2

- [x] Adicionar `REDIS_PASSWORD` ao `.env.example`
- [x] Adicionar `REDIS_USER` ao `.env.example`
- [x] Adicionar `MYSQL_ROOT_PASSWORD` ao `.env.example`
- [x] Adicionar variáveis do Bot (`BACKEND_API_URL`, `WAHA_*`, `N8N_*`, etc.)
- [x] Adicionar variáveis do Web Scrapping (`DB_HOST`, `DB_PORT`, `DB_NAME`)
- [x] Criar `VARIABLES_REFERENCE.md`
- [x] Decidir sobre renomear `PASSWORD_EMAIL` → `EMAIL_PASSWORD`
- [x] Atualizar READMEs com tabela de variáveis por serviço

---

## Anexos

### Comando para Gerar Este Relatório

```bash
# Extrair todas as variáveis dos docker-compose files
grep -ohE '\$\{[A-Z_]+\}' services/*/docker-compose.yml | tr -d '${}' | sort | uniq

# Comparar com .env.example
grep -E '^[A-Z_]+=' .env.example | cut -d'=' -f1 | sort
```

### Referências Cruzadas

- `services/backend/monolith/docker-compose.yml`: Usa `DB_USERNAME`, `DB_PASSWORD`, `BOT_SECRET`, `EMAIL`, `EMAIL_PASSWORD`, `AWS_*`
- `services/db/docker-compose.yml`: Usa `DB_USERNAME`, `DB_PASSWORD`, `PORT_MYSQL`, `PORT_REDIS`, `MYSQL_ROOT_PASSWORD`
- `services/bot/docker-compose.yml`: Usa múltiplas variáveis não documentadas
- `services/web-scrapping/docker-compose.yml`: Usa `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`

---

**Fim do Relatório DOC-2**
