# setup-local.ps1
# Script para levantar todo o ambiente localmente na ordem correta

Set-Location "$PSScriptRoot\.."

# Load GitHub Credentials from .env
Get-Content .env | Foreach-Object {
    $name, $value = $_.split('=', 2)
    if ($name -match "GITHUB_" -or $name -eq "MYSQL_ROOT_PASSWORD" -or $name -eq "DB_PASSWORD") {
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

if ($env:GITHUB_ACCESS_TOKEN -and $env:GITHUB_USERNAME) {
    Write-Host "Realizando login no GitHub Packages..." -ForegroundColor Magenta
    Write-Output $env:GITHUB_ACCESS_TOKEN | docker login ghcr.io -u $env:GITHUB_USERNAME --password-stdin
}

Write-Host "Criando redes Docker do Solarway..." -ForegroundColor Cyan
docker network create solarway_network 2>$null
docker network create storage_network  2>$null

Write-Host "Inicializando a base da infraestrutura (Redes e Bancos)..." -ForegroundColor Cyan

Set-Location services/db
docker-compose --env-file ../../.env up -d

Write-Host "Aguardando MySQL (Monolito) ficar pronto (TCP 3306)..." -ForegroundColor Yellow
$maxRetries = 60   # 180s max
$retries = 0
do {
    $rootPass = if ($env:MYSQL_ROOT_PASSWORD) { $env:MYSQL_ROOT_PASSWORD } else { "06241234" }
    $result = docker exec mysql-db-oltp mysqladmin -u root -p$rootPass -h 127.0.0.1 ping 2>&1
    if ($result -match "mysqld is alive") {
        Write-Host "  MySQL (Monolito) pronto!" -ForegroundColor Green
        break
    }
    $retries++
    Write-Host "  MySQL (Monolito) aguardando TCP... ($retries/$maxRetries)" -ForegroundColor DarkYellow
    Start-Sleep -Seconds 3
} while ($retries -lt $maxRetries)

Write-Host "Inicializando a base do Microserviço (DB e Broker)..." -ForegroundColor Cyan
Set-Location ../backend/microservice
docker-compose --env-file ../../../.env up -d microservice-db microservice-broker

Write-Host "Aguardando MySQL (Microservico) ficar pronto (TCP 3306)..." -ForegroundColor Yellow
$retries = 0
do {
    # Microservice DB usa root password do .env (DB_PASSWORD)
    $microPass = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { "06241234" }
    $result = docker exec microservice-db mysqladmin -u root -p$microPass -h 127.0.0.1 ping 2>&1
    if ($result -match "mysqld is alive") {
        Write-Host "  MySQL (Microservico) pronto!" -ForegroundColor Green
        break
    }
    $retries++
    Write-Host "  MySQL (Microservico) aguardando TCP... ($retries/$maxRetries)" -ForegroundColor DarkYellow
    Start-Sleep -Seconds 3
} while ($retries -lt $maxRetries)

Write-Host "Subindo Monolito (Backend)..." -ForegroundColor Cyan
Set-Location ../monolith
docker-compose --env-file ../../../.env up -d

Write-Host "Subindo App do Microservico..." -ForegroundColor Cyan
Set-Location ../microservice
docker-compose --env-file ../../../.env up -d microservice-app

Write-Host "Inicializando os Frontends..." -ForegroundColor Cyan
Set-Location ../../frontend/management-system
docker-compose --env-file ../../../.env up -d

Set-Location ../institucional-website
docker-compose --env-file ../../../.env up -d

Write-Host "Inicializando o Serviço de Bot..." -ForegroundColor Cyan
Set-Location ../../bot
docker-compose --env-file ../../.env up -d

Write-Host "Inicializando o Nginx Proxy (entry point local)..." -ForegroundColor Cyan
Set-Location ../proxy
# Usa o arquivo LOCAL standalone (sem merge com docker-compose.yml).
# O merge de listas de `ports` no compose apenas adiciona portas, nunca remove —
# então o override não funciona para eliminar portas do arquivo base.
# Em prod/qa usa-se: docker-compose -f docker-compose.yml up -d
docker-compose -f docker-compose.local.yml --env-file ../../.env up -d

Write-Host "Inicializando o Web Scrapping (execução a cada 24h)..." -ForegroundColor Cyan
Set-Location ../web-scrapping
docker-compose --env-file ../../.env up -d

Set-Location ../../
Write-Host ""
Write-Host "======================================================" -ForegroundColor DarkCyan
Write-Host "  Deploy local finalizado!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Interfaces de Usuário:"  -ForegroundColor White
Write-Host "  ➡️  Management System:   http://localhost/" -ForegroundColor Green
Write-Host "  ➡️  Site Institucional:  http://localhost/institucional" -ForegroundColor Green
Write-Host ""
Write-Host "  APIs e Serviços:"  -ForegroundColor White
Write-Host "  ➡️  API Backend (REST):  http://localhost/api" -ForegroundColor Cyan
Write-Host "  ➡️  Schedule Service:    http://localhost/schedule" -ForegroundColor Cyan
Write-Host "  ➡️  Healthcheck Proxy:   http://localhost/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Bot WhatsApp:"  -ForegroundColor White
Write-Host "  ➡️  n8n (fluxos):        http://localhost/n8n" -ForegroundColor Yellow
Write-Host "  ➡️  WAHA (dashboard):    http://localhost/waha/dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Banco de Dados (acesso externo):"  -ForegroundColor White
Write-Host "  ➡️  MySQL:               localhost:3307" -ForegroundColor DarkGray
Write-Host "======================================================" -ForegroundColor DarkCyan
Write-Host ""
