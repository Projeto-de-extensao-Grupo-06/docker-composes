# 📋 VARIABLES_REFERENCE.md — Referência Completa de Variáveis de Ambiente

> Gerado após a auditoria DOC-2. Descreve todas as variáveis usadas no ecossistema Solarway,
> seu escopo, obrigatoriedade e valores padrão.

---

## Legenda

| Símbolo | Significado |
|---------|-------------|
| 🔴 **Obrigatória** | O serviço falha sem ela |
| 🟡 **Recomendada** | Tem valor padrão mas deve ser alterada em produção |
| 🟢 **Opcional** | Possui valor padrão funcional em todos os ambientes |

---

## 1. Banco de Dados (MySQL e Redis)

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `DB_USERNAME` | 🔴 | — | Backend, DB, Web-Scrapping | Usuário do MySQL |
| `DB_PASSWORD` | 🔴 | — | Backend, DB, Web-Scrapping | Senha do MySQL |
| `MYSQL_ROOT_PASSWORD` | 🟡 | `root_password` | DB | Senha do root no MySQL (necessária para init) |
| `PORT_MYSQL` | 🟢 | `3307` | DB | Porta externa do MySQL (host → container) |
| `PORT_REDIS` | 🟢 | `6379` | DB | Porta externa do Redis principal |
| `PORT_BOT_REDIS` | 🟢 | `6380` | Bot | Porta externa do Redis do Bot |
| `REDIS_USER` | 🟢 | `default` | Bot | Usuário do Redis do Bot |
| `REDIS_PASSWORD` | 🟡 | `default` | Bot | Senha do Redis do Bot |
| `PORT_MICROSERVICE_DB` | 🟢 | `3306` | Microservice | Porta do MySQL isolado do microserviço |

---

## 2. Backend (Monolito e Microserviços)

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `EMAIL` | 🔴 | — | Monolito | E-mail do remetente de notificações |
| `EMAIL_PASSWORD` | 🔴 | — | Monolito | Senha/App Password do e-mail |
| `MAIL_HOST` | 🟢 | `smtp.gmail.com` | Monolito | Host SMTP para envio de e-mail |
| `MAIL_PORT` | 🟢 | `587` | Monolito | Porta SMTP |
| `PORT_BACKEND_MONOLITH` | 🟢 | `8000` | Monolito | Porta externa do monolito |
| `PORT_BACKEND_MICROSERVICE` | 🟢 | `8082` | Microservice | Porta externa do microserviço |
| `BOT_SECRET` | 🔴 | — | Monolito, Bot | Chave simétrica para autenticação do bot no backend |

---

## 3. Automação e Bot WhatsApp (n8n + WAHA)

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `PORT_N8N` | 🟢 | `5678` | Bot | Porta externa do n8n |
| `PORT_WAHA` | 🟢 | `3000` | Bot | Porta externa do WAHA |
| `BACKEND_API_URL` | 🟢 | `http://backend-service:8000` | Bot (n8n) | URL interna do backend (rede Docker) |
| `WAHA_API_URL` | 🟢 | `http://bot-waha:3000` | Bot (n8n) | URL interna do WAHA (rede Docker) |
| `N8N_PROTOCOL` | 🟢 | `http` | Bot | Protocolo do n8n (`http` ou `https`) |
| `N8N_HOST` | 🟡 | `localhost` | Bot | Host público do n8n (muda em QA/Prod) |
| `N8N_PORT` | 🟢 | `5678` | Bot | Porta interna do n8n |
| `N8N_BASE_URL` | 🟡 | `http://localhost:5678/` | Bot | URL base do n8n (sobrescrita pelo bootstrap QA) |
| `N8N_WEBHOOK_URL` | 🟡 | `http://localhost:5678/` | Bot | URL de webhooks do n8n (sobrescrita pelo bootstrap QA) |
| `WHATSAPP_HOOK_URL` | 🟡 | `http://bot-n8n:5678/webhook/webhook` | Bot (WAHA) | URL para onde o WAHA envia eventos |
| `WHATSAPP_DEFAULT_ENGINE` | 🟢 | `GOWS` | Bot (WAHA) | Engine do WAHA (`GOWS`, `CHROME`, `WEBJS`) |
| `WHATSAPP_HOOK_EVENTS` | 🟢 | `message` | Bot (WAHA) | Eventos enviados ao webhook |
| `WAHA_NO_API_KEY` | 🟢 | `true` | Bot (WAHA) | Desabilita auth por API key |
| `WAHA_DASHBOARD_NO_PASSWORD` | 🟢 | `true` | Bot (WAHA) | Desabilita senha do dashboard (⚠️ mudar em prod) |
| `WHATSAPP_SWAGGER_NO_PASSWORD` | 🟢 | `true` | Bot (WAHA) | Desabilita senha do Swagger (⚠️ mudar em prod) |

> [!WARNING]
> Em produção, `WAHA_DASHBOARD_NO_PASSWORD` e `WHATSAPP_SWAGGER_NO_PASSWORD` devem ser `false`.

---

## 4. Web Scrapping (Job Batch)

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `DB_HOST` | 🟢 | `mysql-db` | Web-Scrapping | Hostname do MySQL (nome do container) |
| `DB_PORT` | 🟢 | `3306` | Web-Scrapping | Porta interna do MySQL |
| `DB_NAME` | 🟢 | `solarway` | Web-Scrapping | Nome do banco de dados |

> [!NOTE]
> `DB_USER` e `DB_PASSWORD` do web-scrapping mapeiam respectivamente de `DB_USERNAME` e `DB_PASSWORD`.

---

## 5. Frontend

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `PORT_MANAGEMENT_SYSTEM` | 🟢 | `8080` | Frontend | Porta externa do Management System |
| `PORT_INSTITUTIONAL_WEBSITE` | 🟢 | `8081` | Frontend | Porta externa do Site Institucional |

---

## 6. Proxy Central (Nginx)

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `PORT_PROXY` | 🟢 | `80` | Proxy | Porta HTTP do Nginx proxy |

---

## 7. GitHub Packages (GHCR)

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `GITHUB_USERNAME` | 🔴 | — | Todos | Username do GitHub para `docker login ghcr.io` |
| `GITHUB_ACCESS_TOKEN` | 🔴 | — | Todos | Token PAT com permissão `read:packages` |

---

## 8. Cloud AWS

| Variável | Obrig. | Padrão | Serviços | Descrição |
|----------|:------:|--------|----------|-----------|
| `AWS_ACCESS_KEY_ID` | 🔴 | — | Terraform, Backend | Chave de acesso AWS (expira com sessão Academy) |
| `AWS_SECRET_ACCESS_KEY` | 🔴 | — | Terraform, Backend | Chave secreta AWS |
| `AWS_SESSION_TOKEN` | 🟡 | — | Terraform, Backend | Token de sessão (AWS Academy obrigatório) |

| `AWS_KEY_NAME` | 🟡 | `solarway` | Terraform (SSH deploys) | Nome da chave `.pem` na AWS |

---

## 9. Escopo por Ambiente

| Variável | Local | QA | Prod |
|----------|:-----:|:--:|:----:|
| `N8N_BASE_URL` | Localhost | Sobrescrita pelo bootstrap | Via `setup-proxy.sh` |
| `WAHA_DASHBOARD_NO_PASSWORD` | `true` | `true` | ⚠️ `false` |
| `AWS_*` | Sessão local | Não usada na EC2 | Via IAM Instance Profile |

---

**Última atualização:** 2026-04-18 (após auditoria DOC-2)
