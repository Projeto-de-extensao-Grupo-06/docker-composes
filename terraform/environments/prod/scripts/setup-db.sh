#!/bin/bash
# ==============================================================================
# Ambiente: PRODUÃ‡ÃƒO
# Camada: Database EC2
# Objetivo: Bootstrap nativo focado em banco de dados isolado no AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    LOG_FILE="/var/log/solarway-setup.log"
    exec > >(tee -a "$LOG_FILE"|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "âž¡ï¸ [PROD-DB] Iniciando Bootstrap..."
echo "ðŸ“‚ Diretorio atual: $(pwd)"
echo "ðŸ“„ Arquivos em $(pwd):"
ls -la


echo "âž¡ï¸ [PROD-DB] Provisionando com Docker..."

BASE_DIR="/tmp/solarway"
if [ ! -d "$BASE_DIR" ]; then
    echo "âŒ Erro: Diretório $BASE_DIR nÃ£o encontrado!"
    exit 1
fi

cd "$BASE_DIR"

echo 'Aguardando Docker daemon...'
for i in {1..150}; do
    if sudo docker info >/dev/null 2>&1; then
        echo "Docker estÃ¡ pronto!"
        break
    fi
    echo "Aguardando Docker..."
    sleep 2
done

# Login no GitHub Packages (GHCR)
if [ -f .env ]; then
  GITHUB_USERNAME=$(grep GITHUB_USERNAME .env | cut -d'=' -f2 | tr -d '\r')
  GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN .env | cut -d'=' -f2 | tr -d '\r')
  if [ ! -z "$GITHUB_ACCESS_TOKEN" ]; then
    echo "Efetuando login no GHCR..."
    echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  fi
fi

sudo docker network create solarway_network 2>/dev/null || true
sudo docker network create storage_network 2>/dev/null || true
if [ -d "services/db" ]; then
    cd services/db
    echo "âž¡ï¸ [PROD-DB] Pulling images..."
    sudo docker compose pull
    echo "âž¡ï¸ [PROD-DB] Starting containers..."
    sudo docker compose --env-file ../../.env up -d
else
    echo "âŒ Erro: Diretório services/db nÃ£o encontrado!"
    exit 1
fi

echo "[PROD-DB] Provisionamento Finalizado!"

# Healthcheck
sleep 15
if ! nc -z localhost 3306; then
  echo "âŒ MySQL nao responde"
  exit 1
fi

if ! nc -z localhost 6379; then
  echo "âŒ Redis nao responde"
  exit 1
fi

if ! nc -z localhost 3308; then
  echo "âŒ OLAP nao responde"
  exit 1
fi

echo "Database healthcheck OK"
