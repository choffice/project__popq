$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$projects = @(
    'packages\app_core',
    'packages\design_system',
    'apps\customer_app',
    'apps\seller_app'
)

foreach ($project in $projects) {
    $projectPath = Join-Path $workspaceRoot $project
    Write-Host "==> $project"
    Push-Location $projectPath
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        flutter analyze
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        flutter test
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        Pop-Location
    }
}

Write-Host 'POPQ Flutter workspace verification passed.'

