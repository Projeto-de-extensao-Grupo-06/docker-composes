# Infraestrutura AWS (Terraform) - SolarWay

Este diretório armazena o código de provisão de infraestrutura (IaC) via Terraform para o ambiente de **Produção (PROD)**. O ambiente de QA foi descontinuado em favor de uma estratégia de **Pulverização de Deploys** em produção e testes locais via Docker.

## 🏗️ Estrutura Modular

As definições de infraestrutura utilizam módulos padronizados em `modules/` para controle de consistência:

- **vpc**: VPC customizada com isolamento rigoroso entre camadas (Subnets Públicas e Privadas).
- **ec2**: Instâncias Ubuntu 22.04 LTS com configuração automática via User Data e SSM.
- **s3**: Buckets para o Data Lake com criptografia e acesso restrito.

---

## 🚀 Ambiente PROD (`environments/prod`)

O ambiente de produção é segmentado em 5 domínios lógicos. Cada domínio possui seu próprio arquivo de configuração `.tf` e script de deploy para permitir atualizações granulares:

### 1. Database (`database.tf`)
- **Componentes**: MySQL 8.0 e Redis.
- **Isolamento**: Subnet privada dedicada à persistência.

### 2. Backend (`backend.tf`)
- **Componentes**: Monolito Spring Boot e Microserviço de Agendamento.
- **Conectividade**: Acesso via VPC Endpoints ao S3 e comunicação direta com a Zone D (Persistence).

### 3. Frontend (`frontend.tf`)
- **Componentes**: Management System (React) e Institucional Website.
- **Roteamento**: Acesso via Nginx Proxy central.

### 4. Inovação (`innovation.tf`)
- **Componentes**: Chatbot (n8n + WAHA) e Webscraping.
- **Estratégia**: Workers assíncronos para automação de processos.

### 5. Data Lake (`datalake.tf`)
- **Componentes**: S3 (Raw, Trusted, Refined), VPC Endpoints e Grafana.
- **Observabilidade**: O Grafana centraliza métricas de todas as instâncias para visualização em tempo real.

---

## 🛠️ Como Executar o Deploy

NÃO utilize `terraform apply` diretamente sem parâmetros. Utilize os scripts especializados localizados em `prod/scripts/`:

```powershell
# Exemplo: Atualizar apenas o Backend
.\terraform\environments\prod\scripts\deploy-backend.ps1

# Exemplo: Atualizar apenas o Banco de Dados
.\terraform\environments\prod\scripts\deploy-db.ps1
```

### Ordem Recomendada de Provisionamento (Primeiro Deploy)
1. `deploy-db.ps1`
2. `deploy-datalake.ps1`
3. `deploy-backend.ps1`
4. `deploy-inovacao.ps1`
5. `deploy-frontend.ps1`

---

## 🔐 Segurança e Acesso
- **Sem SSH**: O acesso ao terminal é feito exclusivamente via **AWS SSM**.
- **VPC Endpoints**: O tráfego para o S3 não passa pela internet pública.
- **Secrets**: Senhas e tokens são injetados em tempo de execução via SSM Associations, nunca armazenados no código Terraform.
