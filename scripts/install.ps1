# OpenClaw Guide — True one-click install (Windows PowerShell)
# One command, no manual steps after it. You only supply:
#   - an API key (hidden prompt, or $env:OPENCLAW_CUSTOM_API_KEY)
#   - optionally a Telegram bot token (prompt, or $env:TELEGRAM_BOT_TOKEN)
# The script then does everything: install, key/model verify, config
# backup + provider write (with model name, required by OpenClaw
# 2026.11.1+), config validate, Telegram channel, gateway start,
# wait until the gateway answers, channel probe, and a short summary.
# Keys are never printed.
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

function Test-GatewayReady {
  $out = try { openclaw gateway status 2>$null } catch { '' }
  return ($out -match 'Connectivity check: ok') -or ($out -match 'Listening: 127.0.0.1:18789')
}

function Wait-Gateway {
  param([int]$MaxSeconds = 150)
  # A cold gateway takes ~40s to be ready.
  $waited = 0
  while ($waited -lt $MaxSeconds) {
    if (Test-GatewayReady) {
      Write-Host 'Gateway is up (listening on 127.0.0.1:18789).'
      return $true
    }
    $waited += 5
    Write-Host "Waiting for the gateway to answer... ($waited sec / $MaxSeconds sec)"
    Start-Sleep -Seconds 5
  }
  return $false
}

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
  Write-Host "[dry-run] Would install OpenClaw (SkipInstall=$SkipInstall), verify $BaseUrl/models, back up openclaw.json, set primary model to $Provider/$Model, validate the config, add Telegram (if a token is given), start the gateway and wait until it answers, then probe channels. Nothing will change."
  exit 0
}

# 1. Install OpenClaw itself (official installer only).
if (-not $SkipInstall -and -not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
  Write-Host 'Installing OpenClaw (official installer)...'
  iwr -useb https://openclaw.ai/install.ps1 | iex
} else {
  Write-Host 'OpenClaw already installed, or -SkipInstall given. Skipping official installer.'
}
if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
  throw "'openclaw' is not on PATH after install. Reopen PowerShell, then rerun with -SkipInstall."
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
  baseUrl = $BaseUrl; api = 'openai-completions'; models = @(@{ id = $Model; name = $Model })
}) -Force
if (-not $cfg.agents) { $cfg | Add-Member -NotePropertyName agents -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.agents.defaults) { $cfg.agents | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.agents.defaults.model) { $cfg.agents.defaults | Add-Member -NotePropertyName model -NotePropertyValue ([pscustomobject]@{}) }
$cfg.agents.defaults.model.primary = "$Provider/$Model"
# A fresh config also needs at least one agent entry, or the gateway
# refuses to start ("agents.entries must contain at least one
# configured agent"). Preserve an existing entry, only fill what's missing.
if (-not $cfg.agents.entries) { $cfg.agents | Add-Member -NotePropertyName entries -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.agents.entries.main) {
  $cfg.agents.entries | Add-Member -NotePropertyName main -NotePropertyValue ([pscustomobject]@{ workspace = (Join-Path $HOME '.openclaw\workspace') })
}
if (-not $cfg.agents.entries.main.workspace) {
  $cfg.agents.entries.main | Add-Member -NotePropertyName workspace -NotePropertyValue (Join-Path $HOME '.openclaw\workspace') -Force
}
$cfg | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
Write-Host "Wrote provider to $configFile. Primary model: $Provider/$Model"

# 3b. Validate the config now, so a bad config fails here — not later
# at the dashboard or Telegram step.
Write-Host 'Validating config...'
openclaw config validate
if ($LASTEXITCODE -ne 0) { throw 'Config is invalid after writing. Restore the backup in the backups folder and report this.' }
Write-Host 'Config valid.'

# 4. Telegram (optional).
$telegramToken = $env:TELEGRAM_BOT_TOKEN
$telegramAdded = $false
if (-not $SkipTelegram -and -not $telegramToken) {
  $telegramToken = Read-Host 'Telegram bot token (optional, Enter to skip)'
}
if ($telegramToken) {
  Write-Host 'Adding Telegram channel...'
  openclaw channels add --channel telegram --token $telegramToken
  if ($LASTEXITCODE -eq 0) {
    $telegramAdded = $true
  } else {
    Write-Host 'Warning: Telegram channel add failed. Check the token and rerun: openclaw channels add --channel telegram --token <TOKEN>'
  }
}

# 5. Start the gateway and wait until it answers. No manual step after this.
if (Test-GatewayReady) {
  Write-Host 'Gateway is already running. Restarting it so the new config loads...'
  try { openclaw gateway restart } catch {}
  if (-not (Wait-Gateway -MaxSeconds 150)) { throw 'Gateway did not come back up after restart. Run "openclaw gateway status --deep" and check the gateway log.' }
} else {
  try { openclaw gateway install } catch {}
  try { openclaw gateway start } catch {}
  if (-not (Wait-Gateway -MaxSeconds 150)) { throw 'Gateway did not come up. Run "openclaw gateway status --deep" and check the gateway log.' }
}

# 6. Probe channels (best effort — a failed probe does not undo the install).
try { openclaw channels status --probe } catch {}

Write-Host ''
Write-Host 'Done. OpenClaw is running.'
Write-Host '  Dashboard: http://127.0.0.1:18789/'
Write-Host '    - On this machine, run: openclaw dashboard'
Write-Host '    - The dashboard asks for a token. Get it with: openclaw gateway auth-token --show  (never share it)'
if ($telegramAdded) {
  Write-Host '  Telegram: message your bot, then approve pairing with: openclaw pairing approve telegram <CODE>'
}
Write-Host '  Never expose port 18789 to the public internet.'
