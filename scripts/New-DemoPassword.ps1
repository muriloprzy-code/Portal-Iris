[CmdletBinding()]
param(
    [string]$EnvPath = '.env',
    [int]$Length = 24,
    # Replace an existing password (the container applies it on its next start).
    [switch]$Force
)

# Generates a random password for the public demo account and stores it as
# MYOWN_DEMO_USER_PASSWORD in the git-ignored .env only. The value is never printed; whoever
# hosts the demo reads it from .env. docker/demo-start.sh applies it at every container start.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (-not (Test-Path -LiteralPath $path)) { Copy-Item -LiteralPath (Join-Path $root '.env.example') -Destination $path }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([string[]](Get-Content -LiteralPath $path -Encoding UTF8))
$index = -1
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*MYOWN_DEMO_USER_PASSWORD\s*=') { $index = $i } }
if ($index -ge 0 -and $lines[$index] -notmatch '^\s*MYOWN_DEMO_USER_PASSWORD\s*=\s*$' -and -not $Force) {
    Write-Host 'MYOWN_DEMO_USER_PASSWORD is already set in .env; use -Force to replace it.' -ForegroundColor Yellow
    return
}

# Letters and digits only (no characters that need quoting in .env or Compose).
$alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'.ToCharArray()
$bytes = [byte[]]::new($Length)
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$password = -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })

$entry = "MYOWN_DEMO_USER_PASSWORD=$password"
if ($index -ge 0) { $lines[$index] = $entry } else { $lines.Add($entry) }
[IO.File]::WriteAllLines($path, $lines, [Text.UTF8Encoding]::new($false))
Write-Host "A $Length-character demo password was written to $path (MYOWN_DEMO_USER_PASSWORD). It is not shown here." -ForegroundColor Green
