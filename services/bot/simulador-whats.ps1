param(
    [string]$Numero = "5511949902159",
    [string]$Nome = "Ranier",
    [string]$Mensagem = "Oi, sou Ranier e quero realizar um pré orçamento com vocês da Solarqay",
    [boolean]$Producao = $true,
    [string]$WEBHOOK = "http://localhost:5678/webhook-test/webhook"
)

$Url = if ($Producao) { $WEBHOOK } else { "http://localhost:5678/webhook-test/webhook" }

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

try {
    $Response = Invoke-RestMethod -Uri $Url -Method Post -Body $Body -ContentType "application/json"
    Write-Host "Sucesso! O n8n recebeu o gatilho." -ForegroundColor Green
} catch {
    Write-Host "Aviso: Ocorreu um erro ao enviar para o n8n. Verifique se o workflow está ativo ou clique em 'Execute Workflow'." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
