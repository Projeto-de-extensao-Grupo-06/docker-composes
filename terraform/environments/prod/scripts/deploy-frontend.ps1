# deploy-frontend.ps1
# Deploy da camada Frontend (Management + Institucional)

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
    "github_username"= $envVars["GITHUB_USERNAME"]
    "github_token"   = $envVars["GITHUB_ACCESS_TOKEN"]
    "aws_access_key" = $envVars["AWS_ACCESS_KEY_ID"]
    "aws_secret_key" = $envVars["AWS_SECRET_ACCESS_KEY"]
    "aws_session_token" = $envVars["AWS_SESSION_TOKEN"]
}

$varArgs = $TF_VARS.GetEnumerator() | ForEach-Object { "-var=`"$($_.Key)=$($_.Value)`"" }

Write-Host "[DEPLOY - FRONTEND] Iniciando deploy do Frontend..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
terraform apply -auto-approve @varArgs `
    -target=module.ec2_frontend_1 `
    -target=module.ec2_frontend_2 `
    -target=aws_ssm_association.env_frontend_1 `
    -target=aws_ssm_association.env_frontend_2

Set-Location $OriginalPath
Write-Host "[DEPLOY - FRONTEND] Concluído!" -ForegroundColor Green
