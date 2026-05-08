# Infraestrutura de Backend

Este diretório contém a infraestrutura essencial para os serviços de processamento de regras de negócios da aplicação Solarway. A arquitetura é dividida em **Monolito** (Core) e **Microserviços** (Tarefas especializadas).

## 🏗️ Estrutura

- **`monolith/`**: API principal em Spring Boot. Gerencia o banco de dados principal, cache e integração com S3.
- **`microservice/`**: Serviços desacoplados. Atualmente hospeda o `schedule-notification` para agendamento de mensagens.

---

## 📡 Conexões e Endpoints

### Produção (AWS)
Em produção, os backends rodam em subnets privadas. O acesso externo é feito via Nginx Proxy.

| Serviço | Endpoint Interno | Endpoint Público (via Proxy) |
|---------|------------------|------------------------------|
| **Monolito** | `http://<IP_PRIVADO>:8000` | `http://<IP_PRODUTO>/api` |
| **Microserviço** | `http://<IP_PRIVADO>:8082` | `http://<IP_PRODUTO>/schedule` |

### Conectividade Interna
- **Banco de Dados**: Conecta-se ao `mysql-db:3306` via rede `solarway_network`.
- **Cache**: Conecta-se ao `redis-multidb:6379`.
- **Data Lake**: Utiliza **VPC Endpoints** para se comunicar com o S3 sem sair da rede da AWS, garantindo performance e segurança.

---

## 🛠️ Variáveis de Ambiente (Configurações)

As variáveis abaixo devem ser configuradas no arquivo `.env` na raiz da infraestrutura.

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `DB_HOST` | Host do banco de dados | `mysql-db` (Docker) ou IP Privado (AWS) |
| `SPRING_DATASOURCE_URL` | URL JDBC completa | `jdbc:mysql://db-host:3306/solarway` |
| `BUCKET_NAME` | Camada do Data Lake | `solarway-datalake-trusted` |
| `SPRING_PROFILES_ACTIVE`| Perfil do Spring | `prod` ou `dev` |
| `BOT_SECRET` | Token de validação Bot | `chave-secreta-compartilhada` |

---

## 🚀 Estratégia de Deployment

O deploy do backend em produção é realizado de forma isolada para garantir que atualizações na lógica de negócio não afetem a disponibilidade do banco de dados ou do frontend.

**Comando de Deploy (Produção):**
```powershell
.\terraform\environments\prod\scripts\deploy-backend.ps1
```

Este script:
1. Provisiona/Atualiza as instâncias EC2 do Monolito e Microserviço.
2. Injeta as variáveis de ambiente via AWS SSM.
3. Realiza o `docker compose pull` para baixar as versões mais recentes do GHCR.
4. Reinicia os containers com o novo código.
