# Banco de Dados da Aplicação (Storage Domain)

Esta camada é o coração da persistência do Solarway. Ela fornece armazenamento relacional e cache para todos os domínios.

## 🗄️ Componentes
- **MySQL (8.0)**: Banco de dados relacional (Solarway Core).
- **Redis (Multidb)**: Cache de alta performance e gerenciamento de sessões.

---

## 📡 Conexões e Estratégia de Rede

### Acesso Interno (Docker)
Os serviços se conectam via nome do container na rede `solarway_network`:
- **MySQL**: `mysql-db:3306`
- **Redis**: `redis-multidb:6379`

### Acesso em Produção (AWS)
A instância de banco de dados reside em uma **Subnet Privada**.
- **IP Privado**: Variável `DB_HOST` injetada via SSM.
- **Segurança**: Apenas instâncias dentro da VPC (Backends e Bots) podem se conectar às portas 3306 e 6379.
- **External Access**: Bloqueado por padrão. Use SSH Tunneling via Systems Manager se precisar de acesso local (DBeaver/MySQL Workbench).

---

## 🔐 Variáveis e Credenciais

As credenciais são gerenciadas centralmente no arquivo `.env` da raiz:

| Variável | Descrição | Valor Padrão (Local) |
|----------|-----------|----------------------|
| `DB_USERNAME` | Usuário da aplicação | `root` |
| `DB_PASSWORD` | Senha do banco | `06241234` |
| `MYSQL_ROOT_PASSWORD`| Senha root do MySQL | `06241234` |
| `REDIS_PASSWORD` | Senha de acesso ao Redis | `default` |

---

## 🚀 Estratégia de Deployment

O banco de dados é o primeiro componente a ser provisionado. Em produção, ele utiliza uma instância EC2 dedicada para garantir IOPS e estabilidade.

**Comando de Deploy (Produção):**
```powershell
.\terraform\environments\prod\scripts\deploy-db.ps1
```

Este script:
1. Cria a EC2 `database` na subnet privada.
2. Inicializa o MySQL com o script `init.sql` (Schema e Seeds).
3. Configura o Redis com persistência habilitada.
4. Valida a saúde das portas 3306 e 6379 antes de finalizar.
