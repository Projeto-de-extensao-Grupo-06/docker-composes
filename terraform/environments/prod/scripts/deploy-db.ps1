# deploy-db.ps1
# Deploy apenas da camada de Banco de Dados (MySQL + Redis)

$ErrorActionPreference = "Stop"
$OriginalPath = Get-Location
$DotEnvPath = Join-Path $PSScriptRoot "../../../../.env"

# -- Load .env --
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
    "github_username"= $envVars["GITHUB_USERNAME"]
    "github_token"   = $envVars["GITHUB_ACCESS_TOKEN"]
    "aws_access_key" = $envVars["AWS_ACCESS_KEY_ID"]
    "aws_secret_key" = $envVars["AWS_SECRET_ACCESS_KEY"]
    "aws_session_token" = $envVars["AWS_SESSION_TOKEN"]
}

$varArgs = $TF_VARS.GetEnumerator() | ForEach-Object { "-var=`"$($_.Key)=$($_.Value)`"" }

Write-Host "[DEPLOY - DB] Iniciando deploy do Banco de Dados..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
terraform apply -auto-approve @varArgs -target=module.ec2_db -target=aws_ssm_association.env_db

Set-Location $OriginalPath
Write-Host "[DEPLOY - DB] Concluído!" -ForegroundColor Green
