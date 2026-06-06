$ErrorActionPreference = 'Stop'

$envPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
$dashboardPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'admin-dashboard'
$configPath = Join-Path $dashboardPath 'config.js'

if (-not (Test-Path $envPath)) {
  throw '.env was not found.'
}

function Read-EnvValue([string]$key) {
  $line = Get-Content $envPath | Where-Object { $_ -match "^$([regex]::Escape($key))=" } | Select-Object -First 1
  if (-not $line) { return $null }
  return ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
}

$supabaseUrl = Read-EnvValue 'SUPABASE_URL'
$supabaseAnonKey = Read-EnvValue 'SUPABASE_ANON_KEY'

if (-not $supabaseUrl -or -not $supabaseAnonKey) {
  throw 'SUPABASE_URL or SUPABASE_ANON_KEY was not found in .env.'
}

$config = @{
  supabaseUrl = $supabaseUrl
  supabaseAnonKey = $supabaseAnonKey
} | ConvertTo-Json

@"
window.DOWNSVIEW_ADMIN_CONFIG = $config;
"@ | Set-Content -Path $configPath -Encoding UTF8

Write-Host "Wrote admin-dashboard/config.js"
