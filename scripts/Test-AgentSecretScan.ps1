[CmdletBinding()]
param(
    [int]$HistoryDepth = 20,
    [string]$OutputPath = 'test-results/agents-secrets.json'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$startedAt = [DateTimeOffset]::Now
$findings = [System.Collections.Generic.List[object]]::new()

$patterns = [ordered]@{
    'OpenAI key' = 'sk-[A-Za-z0-9_-]{16,}'
    'GitHub token' = 'gh[pousr]_[A-Za-z0-9]{20,}'
    'AWS access key' = 'AKIA[0-9A-Z]{16}'
    'Private key' = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
    # [ \t]* rather than \s*: an empty value must not reach into the next line.
    'Configured AI key' = '(?im)^[ \t]*(?:MYOWN_AI_API_KEY|OPENAI_API_KEY)[ \t]*[:=][ \t]*["'']?[^\s"''#${][^\r\n#]*'
    'Configured demo password' = '(?im)^[ \t]*MYOWN_DEMO_USER_PASSWORD[ \t]*[:=][ \t]*["'']?[^\s"''#${][^\r\n#]*'
    'Configured IRIS password' = '(?im)^[ \t]*IRIS_PASSWORD[ \t]*[:=][ \t]*["'']?(?!SUA_SENHA|CHANGE[-_]?ME|YOUR_PASSWORD|<PASSWORD>)[^\s"''#${][^\r\n#]*'
}

function Add-Finding {
    param([string]$Scope, [string]$Location, [string]$Pattern)
    $findings.Add([pscustomobject]@{ scope = $Scope; location = $Location; pattern = $Pattern })
}

# Windows PowerShell 5.1 (.NET Framework) has no [IO.Path]::GetRelativePath.
function Get-RelativePath {
    param([string]$Path)
    $prefix = $root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $Path.Substring($prefix.Length) }
    return $Path
}

# Scope: what git tracks (git ls-files, which includes the index) plus what is staged for the next
# commit. Untracked and ignored files are out of scope, and .env files never count: they are
# git-ignored and hold the local key by design. Outside a git repository (for example a ZIP
# download) every text file of the folder is scanned instead, with the same exclusions.
$excludedDirectories = @('.tools', 'node_modules', 'dist', 'web\assets', 'test-results')
$textExtensions = @('.cls', '.mac', '.int', '.inc', '.ps1', '.psm1', '.bat', '.cmd', '.sh', '.json', '.xml', '.yaml', '.yml', '.toml', '.md', '.txt', '.env', '.example', '.ts', '.tsx', '.mjs')
$git = Get-Command git -ErrorAction SilentlyContinue
$inRepository = $false
if ($git) {
    # git writes to stderr outside a repository; Windows PowerShell would turn that into an error.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $git.Source -C $root rev-parse --is-inside-work-tree 2>&1 | Out-Null
    $inRepository = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $previous
}
if ($inRepository) {
    $scope = 'tracked or staged'
    $listed = @(& $git.Source -C $root ls-files) + @(& $git.Source -C $root diff --cached --name-only --diff-filter=ACMR)
    if ($LASTEXITCODE -ne 0) { throw 'git could not list the tracked files.' }
} else {
    $scope = 'working-tree (no git repository)'
    $listed = Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object { (Get-RelativePath $_.FullName).Replace('\', '/') } | Where-Object { $_ -notlike '.git/*' }
    Write-Host 'No git repository here: scanning every text file of the folder (except .env and the excluded folders).' -ForegroundColor Yellow
}
$files = $listed | Where-Object { $_ } | Sort-Object -Unique | ForEach-Object {
    $relative = $_.Replace('/', '\')
    $fullPath = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { return }
    $item = Get-Item -LiteralPath $fullPath
    $isEnv = ($item.Name -eq '.env') -or ($item.Name -like '.env.*' -and $item.Name -ne '.env.example')
    if ($isEnv) { return }
    if ($excludedDirectories | Where-Object { $relative -like "$_*" }) { return }
    if ($textExtensions -contains $item.Extension -or $item.Name -in @('Dockerfile', '.env.example')) { $item }
}

foreach ($file in $files) {
    $relative = Get-RelativePath $file.FullName
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    foreach ($entry in $patterns.GetEnumerator()) {
        foreach ($match in [regex]::Matches($content, $entry.Value)) {
            $line = 1 + ($content.Substring(0, $match.Index) -split "`n").Count - 1
            Add-Finding -Scope 'working-tree' -Location "${relative}:$line" -Pattern $entry.Key
        }
    }
}

if ($inRepository -and $HistoryDepth -gt 0) {
    $history = & $git.Source -C $root log -p -n $HistoryDepth -- . 2>$null | Out-String
    foreach ($entry in $patterns.GetEnumerator()) {
        if ([regex]::IsMatch($history, $entry.Value)) {
            Add-Finding -Scope 'recent-git-history' -Location "last-$HistoryDepth-commits" -Pattern $entry.Key
        }
    }
}

$report = [ordered]@{
    suite = 'agents-secret-scan'
    startedAt = $startedAt.ToString('o')
    finishedAt = [DateTimeOffset]::Now.ToString('o')
    status = if ($findings.Count -eq 0) { 'pass' } else { 'fail' }
    scannedFiles = @($files).Count
    historyDepth = $HistoryDepth
    findings = $findings
    summary = [ordered]@{ pass = if ($findings.Count -eq 0) { 1 } else { 0 }; fail = $findings.Count }
}

$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $root $OutputPath }
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8

if ($findings.Count -gt 0) {
    $findings | Format-Table scope, location, pattern -AutoSize
    throw "$($findings.Count) possible secret finding(s) require review. Secret values were intentionally not printed."
}

Write-Host "PASS  SEC-11  No high-confidence secrets were found in $(@($files).Count) $scope files$(if ($inRepository) { " or the last $HistoryDepth commits" })." -ForegroundColor Green
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan
