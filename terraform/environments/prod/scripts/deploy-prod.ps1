# deploy-prod.ps1
# Script para deploy automatizado no ambiente de PRODUCAO do SolarWay
# Uso: .\scripts\deploy-prod.ps1

$ErrorActionPreference = "Stop"

$OriginalPath = Get-Location
$DotEnvPath = Join-Path $PSScriptRoot "../../../../.env"

# -- Carregar todas as variaveis do .env --------------------------------------
if (-not (Test-Path $DotEnvPath)) {
    throw "Arquivo .env nao encontrado em: $DotEnvPath"
}

$envVars = @{}
Get-Content $DotEnvPath | ForEach-Object {
    if ($_ -match "^([^#\s][^=]*)=(.*)$") {
        $envVars[$matches[1].Trim()] = $matches[2].Trim() -replace '^["'']|["'']$', ''
    }
}

# -- Mapear variaveis necessarias para os modulos Terraform (deploy.tf) -------
$TF_VARS = @{
    "db_password"    = $envVars["DB_PASSWORD"]
    "db_username"    = $envVars["DB_USERNAME"]
    "redis_password" = $envVars["REDIS_PASSWORD"]
    "redis_user"     = if ($envVars.ContainsKey("REDIS_USER")) { $envVars["REDIS_USER"] } else { "default" }
    "bot_secret"     = $envVars["BOT_SECRET"]
    "email"          = $envVars["EMAIL"]
    "email_password" = $envVars["EMAIL_PASSWORD"]

    "github_username"= $envVars["GITHUB_USERNAME"]
    "github_token"   = $envVars["GITHUB_ACCESS_TOKEN"]
    "domain"         = if ($envVars.ContainsKey("DOMAIN")) { $envVars["DOMAIN"] } else { "solarway.test" }
    "use_nat_gateway"= if ($envVars.ContainsKey("USE_NAT_GATEWAY")) { $envVars["USE_NAT_GATEWAY"].ToLower() -eq "true" } else { $false }
    "aws_access_key" = $envVars["AWS_ACCESS_KEY_ID"]
    "aws_secret_key" = $envVars["AWS_SECRET_ACCESS_KEY"]
    "aws_session_token" = $envVars["AWS_SESSION_TOKEN"]
    "grafana_user"   = if ($envVars.ContainsKey("GRAFANA_USER")) { $envVars["GRAFANA_USER"] } else { "admin" }
    "grafana_password" = if ($envVars.ContainsKey("GRAFANA_PASSWORD")) { $envVars["GRAFANA_PASSWORD"] } else { "admin" }
}


$varArgs = $TF_VARS.GetEnumerator() | ForEach-Object { 
    $val = $_.Value
    if ($val -is [bool]) { $val = $val.ToString().ToLower() }
    "-var=`"$($_.Key)=$($val)`"" 
}

# -- Pré-download dos ZIPs das Lambdas do GitHub Releases ---------------------
$TerraformDir  = Join-Path $PSScriptRoot ".."
$LambdaZipsDir = Join-Path $TerraformDir ".terraform\lambda_zips"
$GhBase        = "https://github.com/Projeto-de-extensao-Grupo-06/data-analysis/releases/download/latest"

if (-not (Test-Path $LambdaZipsDir)) {
    New-Item -ItemType Directory -Force -Path $LambdaZipsDir | Out-Null
}

Write-Host "[DEPLOY - PROD] Baixando Lambda ZIPs do GitHub Releases..." -ForegroundColor Cyan
foreach ($zip in @("raw_to_trusted.zip", "trusted_to_refined.zip")) {
    $dest = Join-Path $LambdaZipsDir $zip
    if (Test-Path $dest) {
        Write-Host "  -> $zip ja existe, pulando download." -ForegroundColor Yellow
        continue
    }
    Write-Host "  -> $zip" -ForegroundColor Gray
    Invoke-WebRequest -Uri "$GhBase/$zip" -OutFile $dest -UseBasicParsing
    if (-not (Test-Path $dest) -or (Get-Item $dest).Length -eq 0) {
        throw "Falha ao baixar $zip de $GhBase/$zip"
    }
    Write-Host "  OK: $('{0:N1}' -f ((Get-Item $dest).Length / 1MB)) MB baixados." -ForegroundColor Green
}

# -- Terraform Init ------------------------------------------------------------
Write-Host "[DEPLOY - PROD] Inicializando Terraform..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro no terraform init."
}

# -- Terraform Validate --------------------------------------------------------
Write-Host ""
Write-Host "[DEPLOY - PROD] Validando configuracao..." -ForegroundColor Cyan
terraform validate
if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro no terraform validate."
}
Write-Host "  Validacao OK!" -ForegroundColor Green

# -- Terraform Plan ------------------------------------------------------------
Write-Host ""
Write-Host "[DEPLOY - PROD] Executando terraform plan..." -ForegroundColor Cyan
terraform plan -detailed-exitcode @varArgs
$planExit = $LASTEXITCODE

if ($planExit -eq 1) {
    Set-Location $OriginalPath
    throw "Erro no terraform plan."
}

if ($planExit -eq 0) {
    Write-Host "  Nenhuma mudanca detectada. Infra ja esta atualizada." -ForegroundColor Green
    Set-Location $OriginalPath
    exit 0
}

# planExit -eq 2 -> ha mudancas para aplicar
Write-Host ""
$confirm = Read-Host "[DEPLOY - PROD] Deseja aplicar as mudancas acima? (s/N)"
if ($confirm -notin @("s", "S", "sim", "Sim")) {
    Write-Host "  Deploy cancelado pelo usuario." -ForegroundColor Yellow
    Set-Location $OriginalPath
    exit 0
}

# -- Terraform Apply -----------------------------------------------------------
Write-Host ""
Write-Host "[DEPLOY - PROD] Aplicando infra..." -ForegroundColor Cyan
terraform apply -auto-approve @varArgs

if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro no terraform apply."
}

# -- Output final --------------------------------------------------------------
function Get-TFOutput($name) {
    $val = terraform output -raw $name 2>$null
    if ($val) { return $val } else { return "(unavailable)" }
}

$NGINX_IP  = Get-TFOutput "nginx_public_ip"
$NGINX_SSM = Get-TFOutput "nginx_ssm_connect"
$B1_IP     = Get-TFOutput "backend_1_private_ip"
$B1_SSM    = Get-TFOutput "backend_1_ssm_connect"
$B2_IP     = Get-TFOutput "backend_2_private_ip"
$B2_SSM    = Get-TFOutput "backend_2_ssm_connect"
$FE1_IP    = Get-TFOutput "frontend_1_private_ip"
$FE1_SSM   = Get-TFOutput "frontend_1_ssm_connect"
$FE2_IP    = Get-TFOutput "frontend_2_private_ip"
$FE2_SSM   = Get-TFOutput "frontend_2_ssm_connect"
$BOT_IP    = Get-TFOutput "chatbot_private_ip"
$BOT_SSM   = Get-TFOutput "chatbot_ssm_connect"
$WS_IP     = Get-TFOutput "webscraping_private_ip"
$WS_SSM    = Get-TFOutput "webscraping_ssm_connect"
$DB_IP     = Get-TFOutput "db_private_ip"
$DB_SSM    = Get-TFOutput "db_ssm_connect"
$GRAF_IP   = Get-TFOutput "grafana_private_ip"
$GRAF_SSM  = Get-TFOutput "grafana_ssm_connect"

Set-Location $OriginalPath

$sep      = "=" * 68
$log_cmd  = "tail -f /var/log/solarway-setup.log"

Write-Host ""
Write-Host $sep -ForegroundColor Green
Write-Host "  SOLARWAY PROD - Deploy Finalizado" -ForegroundColor Green
Write-Host $sep -ForegroundColor Green

Write-Host ""
Write-Host "  URLS PUBLICAS" -ForegroundColor Cyan
Write-Host "  --------------------------------------------------------------------"
Write-Host "  App (Management):  http://$($NGINX_IP)/"
Write-Host "  API Backend:       http://$($NGINX_IP)/api/"
Write-Host "  Website Instit.:   http://$($NGINX_IP)/institucional/"
Write-Host "  n8n Editor:        http://$($NGINX_IP):5678/"
Write-Host "  WAHA Dashboard:    http://$($NGINX_IP):3000/"
Write-Host "  RabbitMQ Panel:    http://$($NGINX_IP):15672/"
Write-Host "  Grafana Access:    http://$($NGINX_IP):3001/"
Write-Host "  Healthcheck:       http://$($NGINX_IP)/health"
Write-Host "  --------------------------------------------------------------------"

Write-Host ""
Write-Host "  ACESSO SSM + VISUALIZACAO DE LOGS" -ForegroundColor Cyan
Write-Host "  (Conecte via SSM primeiro, depois cole o comando de LOG)" -ForegroundColor Gray
Write-Host ""

Write-Host "  [nginx-proxy] IP: $NGINX_IP (publico)" -ForegroundColor Yellow
Write-Host "  Conectar:  $NGINX_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [backend-1 / monolito] IP: $B1_IP" -ForegroundColor Yellow
Write-Host "  Conectar:  $B1_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [backend-2 / microservice] IP: $B2_IP" -ForegroundColor Yellow
Write-Host "  Conectar:  $B2_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [frontend-1 / institucional] IP: $FE1_IP" -ForegroundColor Yellow
Write-Host "  Conectar:  $FE1_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [frontend-2 / management] IP: $FE2_IP" -ForegroundColor Yellow
Write-Host "  Conectar:  $FE2_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [chatbot / n8n + WAHA] IP: $BOT_IP (privado)" -ForegroundColor Yellow
Write-Host "  Conectar:  $BOT_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [webscraping] IP: $WS_IP" -ForegroundColor Yellow
Write-Host "  Conectar:  $WS_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [database / MySQL + Redis] IP: $DB_IP" -ForegroundColor Yellow
Write-Host "  Conectar:  $DB_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host "  [grafana / observabilidade] IP: $GRAF_IP (privado)" -ForegroundColor Yellow
Write-Host "  Conectar:  $GRAF_SSM"
Write-Host "  Ver Log:   $log_cmd"
Write-Host ""

Write-Host $sep -ForegroundColor Green
Write-Host "  Dica: conecte em uma instancia e rode o comando 'Ver Log' para debug." -ForegroundColor Gray
Write-Host $sep -ForegroundColor Green
Write-Host ""
