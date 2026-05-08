# Solarway - Infraestrutura e Docker Compose

Este repositório contém as configurações de infraestrutura (Cloud e Local) para o ecossistema **Solarway**.

A arquitetura foi **pulverizada** em domínios independentes para facilitar a escalabilidade e o gerenciamento. Atualmente, o projeto suporta dois ambientes principais: **Local (Docker)** e **Produção (AWS Multi-Instance)**.

## 🏗️ Estrutura por Domínios (Serviços)

- **`services/backend/`**: Processamento de dados e lógica de negócio.
  - `monolith/`: API principal Spring Boot.
  - `microservice/`: Serviços auxiliares (Agendamento/Notificação).
- **`services/frontend/`**: Interfaces Web.
  - `institucional-website/`: Landing page e institucional.
  - `management-system/`: Painel administrativo React.
- **`services/bot/`**: Automação inteligente via WhatsApp (n8n + WAHA + Redis).
- **`services/web-scrapping/`**: Job batch para atualização de preços (Mercado Livre).
- **`services/db/`**: Camada de persistência (MySQL + Redis).
- **`services/proxy/`**: Ingress Gateway (Nginx) para roteamento de tráfego.

---

## 💻 Ambiente Local (Desenvolvimento)

Para rodar todo o ecossistema em sua máquina local via Docker Compose:

**Windows (PowerShell):**
```powershell
.\scripts\setup-local.ps1
```

**Linux/Mac (Bash):**
```bash
./scripts/setup-local.sh
```

### Mapa de Acesso Local
| URL | Serviço | Porta Interna |
|-----|---------|---------------|
| `http://localhost/` | Management System | 80 |
| `http://localhost/institucional` | Site Institucional | 80 |
| `http://localhost/api` | API Backend | 8000 |
| `http://localhost:5678` | n8n Editor | 5678 |
| `http://localhost:3000` | WAHA Dashboard | 3000 |

---

## ☁️ Ambiente de Produção (AWS)

A infraestrutura em produção é gerenciada via **Terraform** e dividida em domínios isolados para segurança e performance.

### Estratégia de Deploy Modular
Os deploys foram separados por domínios. Você pode aplicar mudanças em toda a infra ou em partes específicas:

| Script de Deploy | Domínio Afetado | Componentes |
|------------------|-----------------|-------------|
| `deploy-db.ps1` | **Database** | MySQL, Redis |
| `deploy-backend.ps1` | **Backend** | Monolito, Microserviços |
| `deploy-frontend.ps1` | **Frontend** | React Apps (Management & Institucional) |
| `deploy-inovacao.ps1` | **Inovação** | Chatbot (n8n), Webscraping |
| `deploy-datalake.ps1` | **Data Lake** | S3 (Raw/Trusted/Refined), Grafana |

**Localização dos scripts:** `terraform/environments/prod/scripts/`

### Conexões e Estratégia de Rede
- **VPC isolada**: Subnets separadas para cada domínio.
- **NAT Instance**: O Nginx atua como saída para instâncias em subnets privadas (custo zero).
- **Endpoints**: Acesso direto ao S3 via VPC Endpoint para evitar tráfego via internet.
- **SSM Only**: Acesso às instâncias apenas via AWS Systems Manager (sem portas SSH abertas).

---

## 📊 Data Lake e Observabilidade
O projeto utiliza um Data Lake em 3 camadas no S3:
1. **Bronze (Raw)**: Dados brutos coletados.
2. **Silver (Trusted)**: Dados limpos e tipados.
3. **Gold (Refined)**: Dados prontos para BI e Analytics.

**Visualização**: Um dashboard **Grafana** é provisionado automaticamente na camada de Data Lake para monitoramento de métricas e saúde do sistema.

---

## 🔐 Variáveis de Ambiente
Certifique-se de configurar o arquivo `.env` na raiz do projeto com as seguintes chaves obrigatórias:

- `GITHUB_ACCESS_TOKEN`: Para pull de imagens do GHCR.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`: Credenciais da AWS.
- `DB_PASSWORD`, `REDIS_PASSWORD`: Senhas de infraestrutura.
- `EMAIL`, `EMAIL_PASSWORD`: Para notificações do backend.
