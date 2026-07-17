[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host 'Starting HeartAnalysis in local demo mode.'
Write-Host 'Review environment placeholders and use synthetic data before continuing.'
flutter run -d chrome

