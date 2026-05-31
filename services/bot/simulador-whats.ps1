param(
    [string]$Numero = "5511949902159",
    [string]$Nome = "Ranier",
    [string]$Mensagem = "O CEP é 05158430, tenta buscar novamente. A conta média é 400, não 800",
    [boolean]$Producao = $true,
    [string]$WEBHOOK = "http://100.54.46.122:5678/webhook/webhook-test/webhook",
    [boolean]$UseTestWebhook = $true
)

# Resolve o URL com base no ambiente (Local vs Produção) e tipo (Test vs Ativo)
$BaseUrl = if ($Producao) { "http://100.54.46.122:5678" } else { "http://localhost:5678" }
$WebhookType = if ($UseTestWebhook) { "webhook-test" } else { "webhook" }

$Url = if ($PSBoundParameters.ContainsKey('WEBHOOK')) {
    $WEBHOOK
} else {
    "$BaseUrl/$WebhookType/webhook"
}

$Body = @{
    event = "message"
    payload = @{
        from = "$($Numero)@c.us"
        body = $Mensagem
        fromMe = $false
        _data = @{
            Info = @{
                PushName = $Nome
            }
        }
    }
} | ConvertTo-Json -Depth 5

Write-Host "Enviando mensagem simulada para o n8n..." -ForegroundColor Cyan
Write-Host "De: $Nome ($Numero)"
Write-Host "Mensagem: $Mensagem"
Write-Host "URL: $Url"
Write-Host "Payload JSON:" -ForegroundColor DarkGray
Write-Host $Body -ForegroundColor DarkGray

try {
    # Converte o JSON para bytes UTF-8 para forçar o codificação correta no Windows PowerShell
    $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    
    $Response = Invoke-RestMethod -Uri $Url -Method Post -Body $BodyBytes -ContentType "application/json; charset=utf-8"
    Write-Host "Sucesso! O n8n recebeu o gatilho." -ForegroundColor Green
    if ($Response) {
        Write-Host "Resposta do n8n: $Response" -ForegroundColor Gray
    }
} catch {
    Write-Host "Aviso: Ocorreu um erro ao enviar para o n8n." -ForegroundColor Red
    Write-Host "Verifique se o n8n está rodando, se o workflow está ativo ou se você clicou em 'Execute Workflow'." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

