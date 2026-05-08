# deploy-datalake.ps1
# Deploy da camada de Data Lake (S3 + Grafana)

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
    "aws_access_key" = $envVars["AWS_ACCESS_KEY_ID"]
    "aws_secret_key" = $envVars["AWS_SECRET_ACCESS_KEY"]
    "aws_session_token" = $envVars["AWS_SESSION_TOKEN"]
}

$varArgs = $TF_VARS.GetEnumerator() | ForEach-Object { "-var=`"$($_.Key)=$($_.Value)`"" }

Write-Host "[DEPLOY - DATALAKE] Iniciando deploy do Data Lake..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
terraform apply -auto-approve @varArgs `
    -target=module.s3_raw `
    -target=module.s3_trusted `
    -target=module.s3_refined `
    -target=aws_vpc_endpoint.s3 `
    -target=module.ec2_grafana

Set-Location $OriginalPath
Write-Host "[DEPLOY - DATALAKE] Concluído!" -ForegroundColor Green
