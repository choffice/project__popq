param(
    [string]$Email = "seller-db-test@popq.local",
    [string]$SellerName = "DB Test Seller",
    [string]$StoreName = "DB Connection Test Store",
    [int]$TokenDays = 3650
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$baseUrl = "http://localhost:8082"

function Invoke-PopqJson {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PATCH")]
        [string]$Method,
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [hashtable]$Headers,
        [object]$Body
    )

    $arguments = @{
        Method      = $Method
        Uri         = $Uri
        ContentType = "application/json"
    }
    if ($Headers) {
        $arguments.Headers = $Headers
    }
    if ($null -ne $Body) {
        $arguments.Body = $Body | ConvertTo-Json -Depth 10 -Compress
    }
    return Invoke-RestMethod @arguments
}

Push-Location $projectRoot
try {
    $env:POPQ_DEV_LOGIN_ENABLED = "true"
    $env:POPQ_ACCESS_TOKEN_EXPIRATION = "P${TokenDays}D"

    Write-Host "[1/4] Starting MySQL and backend..."
    & docker compose --env-file .env up -d backend
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose failed. Check Docker Desktop and .env."
    }

    Write-Host "[2/4] Waiting for backend health..."
    $healthy = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try {
            $health = Invoke-RestMethod `
                -Method Get `
                -Uri "$baseUrl/actuator/health" `
                -TimeoutSec 2
            if ($health.status -eq "UP") {
                $healthy = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    if (-not $healthy) {
        throw "Backend did not become healthy at $baseUrl."
    }

    Write-Host "[3/4] Issuing seller token..."
    $login = Invoke-PopqJson `
        -Method POST `
        -Uri "$baseUrl/api/v1/dev/auth/login" `
        -Body @{
            email = $Email
            name  = $SellerName
            role  = "SELLER"
        }
    $token = $login.data.accessToken
    $headers = @{ Authorization = "Bearer $token" }

    $storesResponse = Invoke-PopqJson `
        -Method GET `
        -Uri "$baseUrl/api/v1/seller/stores" `
        -Headers $headers
    $stores = @($storesResponse.data)
    $store = $stores |
        Where-Object { $_.name -eq $StoreName } |
        Select-Object -First 1

    if (-not $store) {
        $store = $stores | Select-Object -First 1
    }
    if (-not $store) {
        $created = Invoke-PopqJson `
            -Method POST `
            -Uri "$baseUrl/api/v1/seller/stores" `
            -Headers $headers `
            -Body @{
                storeType  = "LOCAL_STORE"
                name       = $StoreName
                description = "Local seller-web database test store"
                tags       = @("db-test")
            }
        $store = $created.data
    }

    $storeId = [long]$store.storeId
    Invoke-PopqJson `
        -Method PATCH `
        -Uri "$baseUrl/api/v1/seller/stores/$storeId/business-status" `
        -Headers $headers `
        -Body @{ businessStatus = "OPEN" } |
        Out-Null

    Write-Host "[4/4] Copying token to clipboard..."
    $clipboardCopied = $false
    try {
        Set-Clipboard -Value $token
        Start-Sleep -Milliseconds 200
        $clipboardCopied = (Get-Clipboard -Raw).Trim() -eq $token
    } catch {
        $clipboardCopied = $false
    }

    Write-Host ""
    Write-Host "Seller web connection is ready." -ForegroundColor Green
    Write-Host "Store ID    : $storeId"
    Write-Host "Seller email: $Email"
    Write-Host "Token days  : $TokenDays"
    if ($clipboardCopied) {
        Write-Host "Access Token: copied to clipboard (Ctrl+V)" -ForegroundColor Green
    } else {
        Write-Host "Access Token: $token" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Open seller-web, enter Store ID $storeId, and paste the token."
} finally {
    Pop-Location
}
