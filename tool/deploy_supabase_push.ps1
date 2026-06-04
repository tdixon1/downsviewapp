$ErrorActionPreference = 'Stop'

$env:SUPABASE_TELEMETRY_DISABLED = '1'

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  throw 'Set SUPABASE_ACCESS_TOKEN before running this script.'
}

$urlLine = Get-Content .env | Where-Object { $_ -match '^SUPABASE_URL=' } | Select-Object -First 1
if (-not $urlLine) {
  throw 'SUPABASE_URL was not found in .env.'
}

$supabaseUrl = ($urlLine -split '=', 2)[1].Trim()
$projectRef = ([uri]$supabaseUrl).Host.Split('.')[0]

supabase.cmd link --project-ref $projectRef
supabase.cmd db push
supabase.cmd functions deploy send-push-notifications --project-ref $projectRef
