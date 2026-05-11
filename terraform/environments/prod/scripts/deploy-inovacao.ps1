# deploy-inovacao.ps1
# Deploy da camada de Inovação (Chatbot + Webscraping)

$ErrorActionPreference = "Stop"
$OriginalPath = Get-Location
$DotEnvPath = Join-Path $PSScriptRoot "../../../../.env"

$envVars = @{}
Get-Content $DotEnvPath | ForEach-Object {
    if ($_ -match "^([^#\s][^=]*)=(.*)$") {
        $envVars[$matches[1].Trim()] = $matches[2].Trim() -replace '^["'']|["'']$', ''
    }
}

$TF_VARS = @{
    "db_password"    = $envVars["DB_PASSWORD"]
    "db_username"    = $envVars["DB_USERNAME"]
    "redis_password" = $envVars["REDIS_PASSWORD"]
    "bot_secret"     = $envVars["BOT_SECRET"]
    "github_username"= $envVars["GITHUB_USERNAME"]
    "github_token"   = $envVars["GITHUB_ACCESS_TOKEN"]
    "aws_access_key" = $envVars["AWS_ACCESS_KEY_ID"]
    "aws_secret_key" = $envVars["AWS_SECRET_ACCESS_KEY"]
    "aws_session_token" = $envVars["AWS_SESSION_TOKEN"]
}

$varArgs = $TF_VARS.GetEnumerator() | ForEach-Object { "-var=`"$($_.Key)=$($_.Value)`"" }

Write-Host "[DEPLOY - INOVACAO] Iniciando deploy da Inovação..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
if ($LASTEXITCODE -ne 0) { Set-Location $OriginalPath; throw "Erro no terraform init." }

$targets = @(
    "module.ec2_chatbot",
    "module.ec2_webscraping",
    "aws_ssm_association.env_bot",
    "aws_ssm_association.env_webscraping"
) | ForEach-Object { "-target=$_" }

terraform apply -auto-approve @varArgs @targets

if ($LASTEXITCODE -ne 0) { Set-Location $OriginalPath; throw "Erro no terraform apply." }

Set-Location $OriginalPath
Write-Host "[DEPLOY - INOVACAO] Concluído!" -ForegroundColor Green
