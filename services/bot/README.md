# Módulo de Automação e Inovação (Bot WhatsApp)

Este domínio é responsável pela camada de inteligência e interação em tempo real com os clientes via WhatsApp.

## 🤖 Componentes
- **n8n**: Orquestrador de fluxos (Low-code) que processa as mensagens e consulta o backend.
- **WAHA**: WhatsApp HTTP API que gerencia as sessões de WhatsApp Web.
- **Redis (Bot)**: Cache local dedicado para o controle de sessões e filas do WAHA.

---

## 📡 Conexões e Estratégia de Rede

### Produção (AWS)
O domínio de Inovação roda em uma subnet privada isolada.
- **Nginx Ingress**: O acesso externo ao n8n (porta 5678) e WAHA (porta 3000) é roteado pelo Nginx Proxy central.
- **Webhooks**: Os webhooks de mensagens chegam via IP público do Proxy e são encaminhados para o IP privado da instância do Bot.

| URL de Acesso | Destino Interno | Porta |
|---------------|-----------------|-------|
| `http://<IP_PUBLICO>:5678` | Editor n8n | 5678 |
| `http://<IP_PUBLICO>:3000` | Dashboard WAHA | 3000 |

### Integração com o Backend
O Bot comunica-se com o Monolito via IP Privado:
- `BACKEND_API_URL=http://<BACKEND_PRIVATE_IP>:8000`

---

## 🚀 Estratégia de Deployment

O deploy de inovação é independente das camadas de backend e frontend.

**Comando de Deploy (Produção):**
```powershell
.\terraform\environments\prod\scripts\deploy-inovacao.ps1
```

Este script:
1. Provisiona a EC2 `chatbot` e `webscraping`.
2. Injeta variáveis como `BOT_SECRET` e `GITHUB_TOKEN`.
3. Inicia a rede `solarway_network` interna para comunicação WAHA <-> n8n.
4. Realiza o auto-setup do Owner no n8n.

---

## ⚙️ Variáveis de Ambiente
| Variável | Descrição | Valor Sugerido |
|----------|-----------|----------------|
| `BOT_SECRET` | Chave de auth com o backend | `gerar-uuid-seguro` |
| `N8N_HOST` | IP Público para Webhooks | IP do Nginx Proxy |
| `WAHA_API_URL`| Endpoint interno do WAHA | `http://bot-waha:3000` |
