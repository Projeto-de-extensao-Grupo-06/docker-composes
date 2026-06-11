#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Nginx Proxy EC2 (Pública - Substituto do NAT Gateway)
# Objetivo: Configurar e iniciar o Nginx como reverse proxy central.
# Dependências: setup-vm.sh deve ter sido executado antes.
# ==============================================================================
set -e

if [ "$EUID" -eq 0 ]; then
    LOG_FILE="/var/log/solarway-setup.log"
    exec > >(tee -a "$LOG_FILE"|logger -t solarway-proxy -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "[PROD-PROXY] Preparando infraestrutura nativa..."
# Garante repositório universe (onde está o docker.io) e atualiza
sudo add-apt-repository -y universe
sudo apt-get update

echo "[PROD-PROXY] Instalando Docker nativo (docker.io)..."
sudo apt-get install -y docker.io docker-compose-v2 || sudo apt-get install -y docker.io docker-compose

sudo systemctl enable docker
sudo systemctl start docker

echo "[PROD-PROXY] Habilitando Roteador NAT imediatamente..."
sudo sysctl -w net.ipv4.ip_forward=1
PRIMARY_IF=$(ip route | grep default | awk '{print $5}')
sudo iptables -t nat -A POSTROUTING -o $PRIMARY_IF -s 10.0.0.0/24 -j MASQUERADE
sudo iptables -I FORWARD -s 10.0.0.0/24 -j ACCEPT
sudo iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

BASE_DIR="/tmp/solarway"
PROXY_DIR="$BASE_DIR/services/proxy"

# Ler IPs privados da VPC do .env
if [ -f "$BASE_DIR/.env" ]; then
    export BACKEND_PRIVATE_IP=$(grep BACKEND_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export MANAGEMENT_PRIVATE_IP=$(grep MANAGEMENT_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export INSTITUCIONAL_PRIVATE_IP=$(grep INSTITUCIONAL_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export N8N_PRIVATE_IP=$(grep N8N_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export WAHA_PRIVATE_IP=$(grep WAHA_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export DOMAIN=$(grep DOMAIN "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export EMAIL=$(grep EMAIL "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export MICROSERVICE_PRIVATE_IP=$(grep MICROSERVICE_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export GRAFANA_PRIVATE_IP=$(grep GRAFANA_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
else
    echo "[PROD-PROXY] .env nÃ£o encontrado em $BASE_DIR. Abortando."
    exit 1
fi


echo "[PROD-PROXY] IPs configurados:"
echo "      Backend:         ${BACKEND_PRIVATE_IP}:8000"
echo "      Management:      ${MANAGEMENT_PRIVATE_IP}:8080"
echo "      Institucional:   ${INSTITUCIONAL_PRIVATE_IP}:8081"
echo "      n8n/WAHA:        ${N8N_PRIVATE_IP}:5678/3000"

echo "[PROD-PROXY] Processando nginx.conf.template com envsubst..."
cd "$PROXY_DIR"
envsubst '${BACKEND_PRIVATE_IP} ${MANAGEMENT_PRIVATE_IP} ${INSTITUCIONAL_PRIVATE_IP} ${N8N_PRIVATE_IP} ${WAHA_PRIVATE_IP} ${DOMAIN} ${MICROSERVICE_PRIVATE_IP} ${GRAFANA_PRIVATE_IP}' \
    < nginx.conf.template > nginx.conf

echo "[PROD-PROXY] nginx.conf gerado:"
cat nginx.conf

# Gerar Certificados SSL Iniciais (Let's Encrypt)
echo "[PROD-PROXY] Avaliando a presenÃ§a de Certificados SSL para $DOMAIN..."

# Bypass para dominios de teste/locais
if [[ "$DOMAIN" == *".test" || "$DOMAIN" == *".local" || -z "$DOMAIN" ]]; then
    echo "[PROD-PROXY] Dominio local ou vazio ($DOMAIN). Pulo da solicitacao de SSL (Let's Encrypt)."
    echo "   O Nginx devera ser configurado para HTTP (porta 80) apenas."
elif [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "[PROD-PROXY] Certificado ausente."
    
    echo "[PROD-PROXY] Testando conectividade com LetsEncrypt..."
    if ! timeout 2 bash -c 'cat < /dev/null > /dev/tcp/acme-v02.api.letsencrypt.org/443' 2>/dev/null; then
        echo "[PROD-PROXY] Erro: Nao foi possivel alcancar o servidor da LetsEncrypt. Verifique a rota do IGW."
    else
        echo "[PROD-PROXY] Conectividade OK. Solicitando certificado..."
        sudo apt-get update && sudo apt-get install -y certbot
        
        # Garante que a porta 80 esteja livre (o apt pode ter instalado e iniciado o nginx default)
        sudo systemctl stop nginx || true
        
        # Tenta obter o certificado (standalone mode requer porta 80 livre)
        sudo certbot certonly --standalone \
            --non-interactive --agree-tos \
            --register-unsafely-without-email \
            -m "$EMAIL" -d "$DOMAIN" \
            --test-cert || echo "âš ï¸ [PROD-PROXY] Falha ao obter SSL. O Nginx subira em HTTP apenas."
    fi
else
    echo "[PROD-PROXY] Certificado ja existente para $DOMAIN."
fi

echo "[PROD-PROXY] Aguardando Docker daemon (timeout 180s)..."
MAX_WAIT=90
COUNT=0
until sudo docker info >/dev/null 2>&1 || [ $COUNT -eq $MAX_WAIT ]; do
    COUNT=$((COUNT+1))
    echo "   [PROD-PROXY] Docker nao pronto ($COUNT/$MAX_WAIT)..."
    sleep 2
done

if [ $COUNT -eq $MAX_WAIT ]; then
    echo "âŒ [PROD-PROXY] Erro Critico: Docker nao iniciou apos 3 minutos."
    echo "Tentando instalar via apt (docker.io) como fallback..."
    sudo apt-get install -y docker.io
    sudo systemctl start docker
fi

if grep -q "GITHUB_ACCESS_TOKEN" "$BASE_DIR/.env" 2>/dev/null; then
    GITHUB_USERNAME=$(grep GITHUB_USERNAME "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    echo "Iniciando Docker Login em ghcr.io..."
    echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin || true
fi

sudo docker network create solarway_network || true

# Detecta se deve usar "docker compose" ou "docker-compose"
if sudo docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="sudo docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="sudo docker-compose"
else
    echo "Erro: docker compose nao encontrado!"
    exit 1
fi

# Subir o container do proxy
echo "[PROD-PROXY] Iniciando container nginx-proxy usando: $COMPOSE_CMD..."
$COMPOSE_CMD --env-file "$BASE_DIR/.env" up -d

echo "[PROD-PROXY] Nginx Proxy em operaÃ§Ã£o!"
echo "   Healthcheck: curl http://localhost/health"

