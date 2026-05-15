#!/bin/bash
# ==============================================================================
# Solarway - Shared VM Setup Script
# Objetivo: InstalaÃ§Ã£o de Docker e dependÃªncias bÃ¡sicas em VMs Ubuntu/Debian.
# ==============================================================================
set -e

# Configura logs
LOG_FILE="/var/log/solarway-setup-vm.log"
if [ "$EUID" -eq 0 ]; then
    exec > >(tee -a "$LOG_FILE"|logger -t solarway-setup -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "[VM-SETUP] Aguardando conectividade com a internet (NAT Proxy)..."
MAX_RETRIES=30
RETRY_COUNT=0
# Check connectivity to Google DNS via bash (no curl required)
until (6<>/dev/tcp/8.8.8.8/53) &>/dev/null || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo "[VM-SETUP] Sem internet ainda. Tentativa $RETRY_COUNT/$MAX_RETRIES... (Aguardando Proxy/NAT)"
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "[VM-SETUP] Erro Critico: Falha ao obter acesso a internet apos 5 minutos."
    exit 1
fi
echo "[VM-SETUP] Conectividade estabelecida!"

# Aguarda travas do apt (caso o cloud-init esteja rodando algo)
echo "[VM-SETUP] Aguardando liberacao do apt lock..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done

echo "[VM-SETUP] Atualizando repositórios e pacotes básicos..."
sudo apt-get -y update
sudo apt-get -y install -y ca-certificates curl gnupg lsb-release git unzip

echo "[VM-SETUP] Verificando Docker Engine..."
if ! command -v docker &> /dev/null; then
    echo "[VM-SETUP] Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo apt-get install -y docker-compose-plugin || true
else
    echo "[VM-SETUP] Docker já está instalado."
fi

echo "âž¡ï¸  [VM-SETUP] Configurando permissões do Docker..."
sudo systemctl enable docker
sudo systemctl start docker

TARGET_USER=${SUDO_USER:-ubuntu}
if ! id "$TARGET_USER" &>/dev/null; then TARGET_USER="root"; fi
sudo usermod -aG docker "$TARGET_USER" || true

echo "[VM-SETUP] Criando redes Docker padrao do Solarway..."
sudo docker network create solarway_network 2>/dev/null || true
sudo docker network create storage_network 2>/dev/null || true

# Instalação do AWS CLI v2
echo "Baixando e instalando o AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# Limpeza dos arquivos de instalação
rm -rf aws awscliv2.zip
echo "AWS CLI instalado com sucesso!"

echo "[VM-SETUP] Configuracao basica da VM finalizada!"
