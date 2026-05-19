# deploy-datalake.ps1
# Deploy da camada de Data Lake (S3 + Lambdas + Grafana)

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
    "aws_access_key"    = $envVars["AWS_ACCESS_KEY_ID"]
    "aws_secret_key"    = $envVars["AWS_SECRET_ACCESS_KEY"]
    "aws_session_token" = $envVars["AWS_SESSION_TOKEN"]
    "db_username"       = $envVars["DB_USERNAME"]
    "db_password"       = $envVars["DB_PASSWORD"]
    "redis_password"    = $envVars["REDIS_PASSWORD"]
    "redis_user"        = if ($envVars.ContainsKey("REDIS_USER")) { $envVars["REDIS_USER"] } else { "default" }
    "bot_secret"        = $envVars["BOT_SECRET"]
    "email"             = $envVars["EMAIL"]
    "email_password"    = $envVars["EMAIL_PASSWORD"]
    "github_username"   = $envVars["GITHUB_USERNAME"]
    "github_token"      = $envVars["GITHUB_ACCESS_TOKEN"]
    "bucket_name"       = $envVars["BUCKET_NAME"]
    "domain"            = if ($envVars.ContainsKey("DOMAIN")) { $envVars["DOMAIN"] } else { "solarway.test" }
    "grafana_user"      = if ($envVars.ContainsKey("GRAFANA_USER")) { $envVars["GRAFANA_USER"] } else { "admin" }
    "grafana_password"  = if ($envVars.ContainsKey("GRAFANA_PASSWORD")) { $envVars["GRAFANA_PASSWORD"] } else { "admin" }
}

$varArgs = $TF_VARS.GetEnumerator() | ForEach-Object { "-var=`"$($_.Key)=$($_.Value)`"" }

# -- Validação local dos ZIPs das Lambdas --------------------------------------
$TerraformDir  = Join-Path $PSScriptRoot ".."
$LambdaZipsDir = Join-Path $TerraformDir ".terraform\lambda_zips"
if (-not (Test-Path $LambdaZipsDir)) {
    New-Item -ItemType Directory -Force -Path $LambdaZipsDir | Out-Null
}

Write-Host "[DEPLOY - DATALAKE] Validando Lambda ZIPs locais..." -ForegroundColor Cyan
foreach ($zip in @(
    "raw_to_trusted.zip",
    "trusted_to_refined.zip",
    "refined_to_socioeconomic.zip",
    "socioeconomic_to_scoring.zip"
)) {
    $dest = Join-Path $LambdaZipsDir $zip
    Write-Host "  -> $zip" -ForegroundColor Gray
    if (-not (Test-Path $dest) -or (Get-Item $dest).Length -eq 0) {
        throw "Arquivo ausente ou vazio: $dest"
    }
    Write-Host "  OK: $('{0:N1}' -f ((Get-Item $dest).Length / 1MB)) MB encontrados." -ForegroundColor Green
}

# -- Terraform -----------------------------------------------------------------
Write-Host "[DEPLOY - DATALAKE] Iniciando deploy do Data Lake..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
if ($LASTEXITCODE -ne 0) { Set-Location $OriginalPath; throw "Erro no terraform init." }

$targets = @(
    "aws_s3_bucket.datalake",
    "aws_s3_bucket_server_side_encryption_configuration.datalake",
    "aws_s3_bucket_public_access_block.datalake",
    "aws_vpc_endpoint.s3",
    "aws_s3_object.lambda_raw_to_trusted_zip",
    "aws_s3_object.lambda_trusted_to_refined_zip",
    "aws_s3_object.lambda_refined_to_socioeconomic_zip",
    "aws_s3_object.lambda_socioeconomic_to_scoring_zip",
    "aws_lambda_function.raw_to_trusted",
    "aws_lambda_function.trusted_to_refined",
    "aws_lambda_function.refined_to_socioeconomic",
    "aws_lambda_function.socioeconomic_to_scoring",
    "aws_lambda_permission.allow_s3_raw",
    "aws_lambda_permission.allow_s3_trusted",
    "aws_lambda_permission.allow_s3_refined",
    "aws_lambda_permission.allow_s3_socioeconomic",
    "aws_s3_bucket_notification.raw_trigger",
    "aws_s3_bucket_notification.trusted_trigger",
    "aws_s3_bucket_notification.refined_trigger",
    "aws_s3_bucket_notification.socioeconomic_trigger",
    "module.ec2_grafana",
    "aws_ssm_association.env_grafana"
) | ForEach-Object { "-target=$_" }

terraform apply -auto-approve @varArgs @targets

if ($LASTEXITCODE -ne 0) { Set-Location $OriginalPath; throw "Erro no terraform apply." }

Set-Location $OriginalPath
Write-Host "[DEPLOY - DATALAKE] Concluído!" -ForegroundColor Green
