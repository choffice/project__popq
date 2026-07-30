param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("customer", "seller")]
    [string]$App
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$configuration = if ($App -eq "customer") {
    @{
        Project = "customer_app"
        Port = 5183
    }
} else {
    @{
        Project = "seller_app"
        Port = 5184
    }
}
$appPath = Join-Path $projectRoot "mobile_flutter\apps\$($configuration.Project)"

Push-Location $appPath
try {
    & flutter run `
        -d chrome `
        "--web-port=$($configuration.Port)" `
        --dart-define=POPQ_FLAVOR=development `
        --dart-define=POPQ_API_BASE_URL=http://localhost:8082
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
