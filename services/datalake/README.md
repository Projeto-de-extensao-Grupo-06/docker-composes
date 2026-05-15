# Solarway Data Lake

Este documento detalha a arquitetura do Data Lake da Solarway, as camadas de dados e as decisões arquiteturais adotadas durante a concepção do projeto.

## Estrutura do Data Lake (Arquitetura Medalhão)

Os dados fluem através de três camadas principais, representadas por buckets S3:
- **Raw (Bruto):** `solarway-datalake-raw`. Onde os dados são ingeridos em seu formato original (JSON, CSV, etc.).
- **Trusted (Confiável):** `solarway-datalake-trusted`. Onde os dados passam por limpeza, tipagem e padronização.
- **Refined (Refinado):** `solarway-datalake-refined`. Onde os dados são enriquecidos e modelados para consumo final (Business Intelligence).

> [!NOTE]
> **Provisionamento de Buckets:**
> Todos os buckets S3 são provisionados dinamicamente via Terraform (`datalake.tf`), concatenando um sufixo (Account ID da AWS) para garantir nomes globalmente únicos.
> Portanto, a variável de ambiente `BUCKET_NAME` anteriormente configurada no arquivo `.env` foi declarada **obsoleta/inútil**, pois os serviços interagem com os recursos consumindo dados propagados internamente ou passados por injeção na AWS diretamente pelas configurações do Terraform (sem depender de configuração estática).

---

## Decisões Arquiteturais e Open Questions

### 1. Banco OLAP vs AWS Athena

Para o consumo dos dados da camada Refined através do Grafana (Observabilidade e Análise), optamos por não utilizar o AWS Athena.

**Decisão:** O banco OLAP será um **MySQL simples com um modelo Star Schema**, hospedado na própria EC2 de banco de dados do ambiente.
**Motivo:** No escopo do nosso projeto, ter o MySQL processando as consultas analíticas centraliza a infraestrutura de dados relacionais na mesma instância e evita a introdução de novos serviços Serverless de billing por query (como o Athena), simplificando o gerenciamento do projeto.

### 2. AWS Glue vs AWS Lambda (ETL)

O processamento dos dados entre as camadas do Data Lake (Raw -> Trusted -> Refined) está sendo feito por funções **AWS Lambda**.

**Avaliação (Glue vs Lambda):**
- O AWS Glue é um serviço gerenciado focado em ETL robusto e Big Data.
- O AWS Lambda possui limitações de tempo de execução (15 minutos) e memória.
**Decisão:** Optou-se pelas **Lambdas** pois a decisão reflete o escopo de um projeto acadêmico focado em inovação, onde os gargalos de escalabilidade extrema, quantidade massiva de dados e esforço computacional contínuo não são as premissas primárias do momento. A Lambda atende bem aos volumes e à prova de conceito que estamos desenvolvendo.

---

## Integração CI/CD (Lambdas)

O deploy das funções Lambdas é automatizado. Elas consomem os pacotes `.zip` diretamente do repositório `data-analysis` no GitHub Releases:
- `raw_to_refined.zip` (traduzido funcionalmente para ingestão inicial / movimentação para a camada trusted na arquitetura de bucket).
- `trusted_to_refined.zip` (movimentação final para consumo).

O Terraform provisiona essas funções atrelando a `LabRole` existente para garantir as permissões necessárias.
