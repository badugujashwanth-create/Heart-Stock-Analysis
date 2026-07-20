[CmdletBinding()]
param(
    [int]$ApiPort = 8000,
    [int]$WebPort = 8085
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $repoRoot 'backend'
$frontendRoot = Join-Path $repoRoot 'frontend'
$python = Join-Path $backendRoot '.venv\Scripts\python.exe'

if (-not (Test-Path $python)) {
    throw 'Create backend/.venv and install backend/requirements-dev.txt before running the demo.'
}

Write-Host 'Starting HeartAnalysis in local demo mode.'
Write-Host 'Use the built-in synthetic example only. Do not enter real patient data.'

$env:APP_ENV = 'development'
$env:AI_PROVIDER = 'rules'
$env:SQLITE_PATH = 'data/demo.db'
$env:CORS_ORIGINS = "http://127.0.0.1:$WebPort"
$env:PERSIST_PREDICTIONS = 'true'

$backend = Start-Process `
    -FilePath $python `
    -ArgumentList '-m', 'app.main' `
    -WorkingDirectory $backendRoot `
    -WindowStyle Hidden `
    -PassThru

try {
    Set-Location $frontendRoot
    flutter run -d web-server `
        --web-hostname 127.0.0.1 `
        --web-port $WebPort `
        --dart-define="API_BASE_URL=http://127.0.0.1:$ApiPort"
}
finally {
    if (-not $backend.HasExited) {
        Stop-Process -Id $backend.Id
    }
}
