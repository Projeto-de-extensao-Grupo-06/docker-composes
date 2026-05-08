#!/bin/bash
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Bot EC2 (WhatsApp WAHA & n8n / Webscraping)
# Objetivo: Bootstrap das engines de bot e webscraping.
# Dependências: setup-vm.sh deve ter sido executado antes.
#
# IMPORTANTE: Em PROD, o bot roda em instância SEPARADA do backend.
# A comunicação com o backend é feita via IP PRIVADO da VPC (não hostname Docker).
# O BACKEND_API_URL é injetado pelo SSM Association (env.bot.tmpl) com o IP real.
# ==============================================================================
set -e

if [ "$EUID" -eq 0 ]; then
    LOG_FILE="/var/log/solarway-setup.log"
    exec > >(tee -a "$LOG_FILE"|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "âž¡ï¸ [PROD-BOT] Iniciando Bootstrap (BOT_TYPE=$BOT_TYPE)..."
echo "ðŸ“‚ Diretorio atual: $(pwd)"
echo "ðŸ“„ Arquivos em $(pwd):"
ls -la


BASE_DIR="/tmp/solarway"

if [ ! -d "$BASE_DIR" ]; then
    echo "Erro: Diretório $BASE_DIR não encontrado. setup-vm.sh rodou?"
    exit 1
fi

cd "$BASE_DIR"

echo "[PROD-BOT] Aguardando Docker daemon..."
for i in {1..150}; do
    if sudo docker info > /dev/null 2>&1; then
        echo "Docker pronto!"
        break
    fi
    echo "Docker nÃ£o pronto, tentativa $i/30..."
    sleep 4
done

# Login no GHCR
if [ -f .env ]; then
    GITHUB_USERNAME=$(grep GITHUB_USERNAME .env | cut -d'=' -f2 | tr -d '\r')
    GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN .env | cut -d'=' -f2 | tr -d '\r')
    if [ -n "$GITHUB_ACCESS_TOKEN" ]; then
        echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
    fi
fi

# Chatbot Stack (n8n + WAHA + Redis)
sudo docker network create solarway_network 2>/dev/null || true
sudo docker network create storage_network 2>/dev/null || true
if [[ "$BOT_TYPE" == "chatbot" || -z "$BOT_TYPE" ]]; then
    echo "[PROD-BOT] Iniciando Chatbot Stack (n8n + WAHA + Redis)..."
    if [ -d "services/bot" ]; then
        cd services/bot
        sudo docker compose pull
        # Usa o .env injetado via SSM (BACKEND_API_URL contÃ©m o IP privado real do backend)
        sudo docker compose --env-file ../../.env up -d
        cd ../..
        echo "[PROD-BOT] Chatbot Stack iniciada!"
        echo "   n8n:  http://$(hostname -I | awk '{print $1}'):5678"
        echo "   WAHA: http://$(hostname -I | awk '{print $1}'):3000/dashboard"
    else
        echo "Erro: services/bot nÃ£o encontrado!"
        exit 1
    fi
fi

# Web Scrapping (Job Batch)
if [[ "$BOT_TYPE" == "webscraping" ]]; then
    echo "[PROD-BOT] Iniciando Web Scrapping Job..."
    if [ -d "services/web-scrapping" ]; then
        cd services/web-scrapping
        sudo docker compose pull
        sudo docker compose --env-file ../../.env up -d
        cd ../..
        echo "[PROD-BOT] Web Scrapping Job iniciado!"
    else
        echo "Erro: services/web-scrapping não encontrado!"
        exit 1
    fi
fi

# Grafana (Observability)
if [[ "$BOT_TYPE" == "grafana" ]]; then
    echo "[PROD-BOT] Iniciando Grafana Stack..."
    if [ -d "services/grafana" ]; then
        cd services/grafana
        sudo docker compose pull
        sudo docker compose --env-file ../../.env up -d
        cd ../..
        echo "[PROD-BOT] Grafana Stack iniciada!"
    else
        echo "Erro: services/grafana não encontrado!"
        exit 1
    fi
fi

echo "[PROD-BOT] Provisionamento Finalizado! (BOT_TYPE=$BOT_TYPE)"
