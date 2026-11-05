# OpenClaw Guide — One-click install (Windows PowerShell)
# For a NEW machine, for everyone. Backs up $HOME\.openclaw\openclaw.json
# before any change and never deletes the backup. Keys are never printed.
#
# Usage:
#   .\install.ps1
#   .\install.ps1 -BaseUrl https://api.example.com/v1 -Model your-model-id
#   $env:OPENCLAW_CUSTOM_API_KEY = '...' ; .\install.ps1 -DryRun
param(
  [string]$BaseUrl = $env:OPENCLAW_BASE_URL,
  [string]$Model = $env:OPENCLAW_MODEL,
  [string]$Provider = $(if ($env:OPENCLAW_PROVIDER) { $env:OPENCLAW_PROVIDER } else { 'myprovider' }),
  [switch]$DryRun,
  [switch]$SkipInstall,
  [switch]$SkipTelegram
)
$ErrorActionPreference = 'Stop'

if (-not $BaseUrl) { $BaseUrl = Read-Host 'Custom Base URL (e.g. https://api.example.com/v1)' }
if (-not $Model) { $Model = Read-Host 'Model ID (e.g. your-model-id)' }
$apiKey = $env:OPENCLAW_CUSTOM_API_KEY
if (-not $apiKey) {
  $secure = Read-Host 'API key (hidden)' -AsSecureString
  $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
if (-not $BaseUrl) { throw 'Base URL is required.' }
if (-not $Model) { throw 'Model ID is required.' }
if (-not $apiKey) { throw 'API key is required.' }

if ($DryRun) {
  Write-Host "[dry-run] Would install OpenClaw (SkipInstall=$SkipInstall), verify $BaseUrl/models, back up openclaw.json, and set primary model to $Provider/$Model."
  exit 0
}

# 1. Install OpenClaw itself (official installer only).
if (-not $SkipInstall -and -not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
  Write-Host 'Installing OpenClaw (official installer)...'
  iwr -useb https://openclaw.ai/install.ps1 | iex
} else {
  Write-Host 'OpenClaw already installed, or -SkipInstall given. Skipping official installer.'
}

# 2. Verify the key + model before writing anything.
Write-Host "Verifying API key against $BaseUrl/models ..."
try {
  $models = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers @{ Authorization = "Bearer $apiKey" } -TimeoutSec 30
  $modelText = ($models | ConvertTo-Json -Depth 5)
  if ($modelText -notmatch [regex]::Escape($Model)) {
    Write-Host "Warning: model '$Model' was not listed by $BaseUrl/models. Continuing anyway."
  }
} catch {
  throw "Could not reach $BaseUrl/models. Check the base URL (401 = key, 404 = URL). Nothing was written. $($_.Exception.Message)"
}

# 3. Back up, then merge the provider config.
$configDir = Join-Path $HOME '.openclaw'
$configFile = Join-Path $configDir 'openclaw.json'
$backupDir = Join-Path $configDir 'backups'
New-Item -ItemType Directory -Force -Path $configDir, $backupDir | Out-Null
if (Test-Path $configFile) {
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  Copy-Item $configFile (Join-Path $backupDir "openclaw.json.$ts")
  Write-Host "Backed up existing config to $backupDir\openclaw.json.$ts"
}
try {
  $cfg = if (Test-Path $configFile) { Get-Content $configFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
} catch {
  throw 'Existing config is not plain JSON. It was backed up, but not merged. Merge it by hand from templates/openclaw.json.example.'
}
if (-not $cfg.models) { $cfg | Add-Member -NotePropertyName models -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.models.providers) { $cfg.models | Add-Member -NotePropertyName providers -NotePropertyValue ([pscustomobject]@{}) }
$cfg.models.providers | Add-Member -NotePropertyName $Provider -NotePropertyValue ([pscustomobject]@{
  baseUrl = $BaseUrl; api = 'openai-completions'; models = @(@{ id = $Model })
}) -Force
if (-not $cfg.agents) { $cfg | Add-Member -NotePropertyName agents -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.agents.defaults) { $cfg.agents | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.agents.defaults.model) { $cfg.agents.defaults | Add-Member -NotePropertyName model -NotePropertyValue ([pscustomobject]@{}) }
$cfg.agents.defaults.model.primary = "$Provider/$Model"
$cfg | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
Write-Host "Wrote provider to $configFile. Primary model: $Provider/$Model"

# 4. Telegram (optional).
$telegramToken = $env:TELEGRAM_BOT_TOKEN
if (-not $SkipTelegram -and -not $telegramToken) {
  $telegramToken = Read-Host 'Telegram bot token (optional, Enter to skip)'
}
if ($telegramToken -and (Get-Command openclaw -ErrorAction SilentlyContinue)) {
  try { openclaw channels add --channel telegram --token $telegramToken } catch { Write-Host 'Warning: Telegram channel add failed. Check the token.' }
}

# 5. Gateway service + status.
if (Get-Command openclaw -ErrorAction SilentlyContinue) {
  try { openclaw gateway install } catch {}
  try { openclaw gateway status } catch { Write-Host "Run 'openclaw gateway status' and 'openclaw dashboard' to check the gateway." }
}

Write-Host ''
Write-Host 'Done. Next:'
Write-Host '  1. Run: openclaw dashboard   (opens http://127.0.0.1:18789/)'
Write-Host '  2. If you added Telegram: message your bot, then approve pairing.'
Write-Host '  3. Never expose port 18789 to the public internet.'
