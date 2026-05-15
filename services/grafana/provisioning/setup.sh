#!/bin/sh

BASE="http://grafana:3000"
AUTH="${GRAFANA_USER}:${GRAFANA_PASSWORD}"

echo "==> Aguardando Grafana estar totalmente pronto..."
sleep 5

echo "==> Criando playlist Observability..."
curl -sf -X POST "$BASE/api/playlists" \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Observability",
    "uid":  "playlist-observability",
    "interval": "5m",
    "items": [
      { "type": "dashboard_by_tag", "value": "observability", "order": 1, "title": "Observability" }
    ]
  }'

echo ""
echo "==> Criando playlist Analytics..."
curl -sf -X POST "$BASE/api/playlists" \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Analytics",
    "uid":  "playlist-analytics",
    "interval": "5m",
    "items": [
      { "type": "dashboard_by_tag", "value": "analytics", "order": 1, "title": "Analytics" }
    ]
  }'

echo ""
echo "==> Criando pasta Analytics e restringindo acesso..."
# Criar pasta "Analytics" e restringir acesso
FOLDER=$(curl -sf -X POST "$BASE/api/folders" \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"title":"Analytics","uid":"folder-analytics"}')

# Dar permissão de Viewer apenas para usuário específico (userId=2)
# NOTA: O ID do usuário pode precisar ser ajustado conforme o seu ambiente.
curl -sf -X POST "$BASE/api/folders/folder-analytics/permissions" \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      { "userId": 2, "permission": 1 }
    ]
  }'

echo ""
echo "==> Setup concluído."
