[CmdletBinding()]
param(
  [string]$BaseUrl = 'http://127.0.0.1:8085',
  [switch]$UseExistingServices,
  [switch]$SkipBrowserInstall,
  [switch]$SmokeOnly,
  [string]$FfmpegPath = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backendDir = Join-Path $repoRoot 'backend'
$frontendDir = Join-Path $repoRoot 'frontend'
$demoDir = Join-Path $repoRoot 'docs\demo'
$verificationDir = Join-Path $demoDir 'verification'
[IO.Directory]::CreateDirectory($verificationDir) | Out-Null
$ownedProcesses = @()

function Stop-ProcessTree([int]$ProcessId) {
  $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue
  foreach ($child in $children) { Stop-ProcessTree -ProcessId $child.ProcessId }
  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Resolve-Ffmpeg([string]$RequestedPath) {
  if ($RequestedPath) { return (Resolve-Path $RequestedPath).Path }
  $installed = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if ($null -ne $installed) { return $installed.Source }
  $cache = Join-Path $env:TEMP 'workhub-ffmpeg-8.1.2'
  $cached = Get-ChildItem $cache -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -ne $cached) { return $cached.FullName }
  throw 'FFmpeg was not found. Install it or pass -FfmpegPath.'
}

function Wait-ForDemo {
  for ($attempt = 0; $attempt -lt 120; $attempt += 1) {
    try {
      $api = Invoke-RestMethod -Uri 'http://127.0.0.1:8000/healthz' -TimeoutSec 2
      $web = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 2
      if ($api.status -eq 'ok' -and $web.StatusCode -eq 200) { return }
    } catch { Start-Sleep -Seconds 1 }
  }
  throw 'Demo services did not become healthy within 120 seconds.'
}

function New-Narration([string]$OutputPath) {
  Add-Type -AssemblyName System.Speech
  $paragraphs = (Get-Content -Raw -Encoding utf8 (Join-Path $demoDir 'NARRATION.md')) -split '(?:\r?\n){2,}' |
    Where-Object { $_ -and $_ -notmatch '^#' } |
    ForEach-Object { ($_ -replace '[`*_#]', '').Trim() }
  $builder = New-Object System.Speech.Synthesis.PromptBuilder
  foreach ($paragraph in $paragraphs) {
    $builder.AppendText($paragraph)
    $builder.AppendBreak([TimeSpan]::FromSeconds(2))
  }
  $voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
  try {
    $voice.Rate = -1
    $voice.Volume = 90
    $voice.SetOutputToWaveFile($OutputPath)
    $voice.Speak($builder)
  } finally { $voice.Dispose() }
}

$ffmpeg = Resolve-Ffmpeg $FfmpegPath
$ffprobe = Join-Path (Split-Path -Parent $ffmpeg) 'ffprobe.exe'
if (-not (Test-Path $ffprobe)) { throw 'ffprobe.exe was not found beside FFmpeg.' }

try {
  if (-not $UseExistingServices) {
    Push-Location $frontendDir
    try {
      flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
      if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
    } finally { Pop-Location }

    $env:APP_ENV = 'development'
    $env:AI_PROVIDER = 'rules'
    $env:SQLITE_PATH = 'data/demo.db'
    $env:CORS_ORIGINS = $BaseUrl
    $env:PERSIST_PREDICTIONS = 'true'
    $ownedProcesses += Start-Process -FilePath (Join-Path $backendDir '.venv\Scripts\python.exe') -ArgumentList '-m','app.main' -WorkingDirectory $backendDir -WindowStyle Hidden -PassThru
    $ownedProcesses += Start-Process -FilePath 'python' -ArgumentList '-m','http.server','8085' -WorkingDirectory (Join-Path $frontendDir 'build\web') -WindowStyle Hidden -PassThru
  }

  Wait-ForDemo
  $recordingStartedAt = Get-Date
  $env:DEMO_BASE_URL = $BaseUrl.TrimEnd('/')
  $env:DEMO_FAST = if ($SmokeOnly) { 'true' } else { 'false' }
  if (-not $SkipBrowserInstall) { npx playwright install chromium }
  npx playwright test scripts/record-workflow.spec.ts --workers=1 --reporter=line
  if ($LASTEXITCODE -ne 0) { throw 'The complete product simulation failed.' }
  if ($SmokeOnly) { Write-Host 'The recording workflow passed in smoke mode.'; return }

  $sourceVideo = Get-ChildItem (Join-Path $repoRoot 'test-results') -Filter '*.webm' -Recurse |
    Where-Object { $_.LastWriteTime -ge $recordingStartedAt } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($null -eq $sourceVideo) { throw 'Playwright produced no new WebM.' }

  $workDir = Join-Path $env:TEMP ('heart-video-' + [guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($workDir) | Out-Null
  $narration = Join-Path $workDir 'narration.wav'
  $output = Join-Path $demoDir 'demo.webm'
  New-Narration $narration

  $sourceProbe = (& $ffprobe -v error -show_entries format=duration -of json $sourceVideo.FullName) | Out-String | ConvertFrom-Json
  $duration = [double]$sourceProbe.format.duration
  if ($duration -lt 180) { throw "Recorded simulation is too short: $duration seconds." }

  $audioFilter = "[1:a]apad=pad_dur=$duration[a]"
  & $ffmpeg -hide_banner -loglevel warning -y -i $sourceVideo.FullName -i $narration `
    -filter_complex $audioFilter -map 0:v:0 -map '[a]' `
    -c:v libvpx-vp9 -crf 38 -b:v 0 -deadline realtime -cpu-used 8 -row-mt 1 `
    -c:a libopus -b:a 64k -t $duration $output
  if ($LASTEXITCODE -ne 0) { throw 'Final demo encoding failed.' }

  & $ffmpeg -hide_banner -loglevel error -y -ss '00:01:12' -i $output -frames:v 1 (Join-Path $demoDir 'demo-thumbnail.png')
  $frameTimes = @('00:00:10','00:00:38','00:01:02','00:01:28','00:01:52','00:02:15','00:02:40','00:03:02','00:03:28','00:03:52')
  for ($index = 0; $index -lt $frameTimes.Count; $index += 1) {
    & $ffmpeg -hide_banner -loglevel error -y -ss $frameTimes[$index] -i $output -frames:v 1 (Join-Path $verificationDir ('{0:D2}-frame.png' -f ($index + 1)))
  }

  $probeJson = (& $ffprobe -v error -show_entries 'format=duration,size:stream=codec_type,codec_name,width,height' -of json $output) | Out-String
  $probe = $probeJson | ConvertFrom-Json
  $videoStream = $probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
  $audioStream = $probe.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
  if ([double]$probe.format.duration -lt 180 -or $videoStream.width -ne 1280 -or $videoStream.height -ne 720 -or $null -eq $audioStream) { throw 'Demo acceptance failed.' }

  $hash = (Get-FileHash -Algorithm SHA256 $output).Hash.ToLower()
  $evidence = [ordered]@{
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    duration_seconds = [Math]::Round([double]$probe.format.duration, 3)
    width = $videoStream.width
    height = $videoStream.height
    video_codec = $videoStream.codec_name
    audio_codec = $audioStream.codec_name
    browser = 'Playwright bundled Chromium'
    data_boundary = 'Deterministic synthetic profile; rules provider; local opt-in persistence'
    workflow = 'Synthetic input -> scorecard -> what-if -> history -> assistant -> close'
    captions = 'demo-captions.vtt'
    sha256 = $hash
    bytes = (Get-Item $output).Length
    verification_frames = $frameTimes.Count
    frame_timestamps = $frameTimes
  }
  [IO.File]::WriteAllText((Join-Path $verificationDir 'verification.json'), ($evidence | ConvertTo-Json) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $demoDir 'demo.sha256'), "$hash  demo.webm$([Environment]::NewLine)", [Text.UTF8Encoding]::new($false))
  $evidence | ConvertTo-Json
} finally {
  foreach ($process in $ownedProcesses) {
    if ($process -and -not $process.HasExited) { Stop-ProcessTree -ProcessId $process.Id }
  }
}
