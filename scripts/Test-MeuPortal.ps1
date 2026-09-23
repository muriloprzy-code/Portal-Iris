[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52773',
    [PSCredential]$Credential
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

function Test-Condition {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "PASS  $Message" -ForegroundColor Green
    } else {
        Write-Host "FAIL  $Message" -ForegroundColor Red
        $failures.Add($Message)
    }
}

function Get-StatusCode {
    param([scriptblock]$Request)
    try {
        $response = & $Request
        return [int]$response.StatusCode
    } catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        throw
    }
}

$portalUrl = "$($BaseUrl.TrimEnd('/'))/meuportal/index.html"
$portal = Invoke-WebRequest -UseBasicParsing -Uri $portalUrl -MaximumRedirection 5
Test-Condition ($portal.StatusCode -eq 200) 'Production portal returns HTTP 200.'
Test-Condition ($portal.Content -match '<div id="root"></div>') 'Production HTML contains the React root element.'

$assetMatches = [regex]::Matches($portal.Content, '(?:src|href)="(?<path>/meuportal/assets/[^"]+)"')
Test-Condition ($assetMatches.Count -ge 2) 'Production HTML references compiled JavaScript and CSS assets.'
foreach ($match in $assetMatches) {
    $assetUrl = "$($BaseUrl.TrimEnd('/'))$($match.Groups['path'].Value)"
    $asset = Invoke-WebRequest -UseBasicParsing -Uri $assetUrl
    Test-Condition ($asset.StatusCode -eq 200 -and $asset.RawContentLength -gt 0) "Asset is available: $($match.Groups['path'].Value)"
}

$healthUrl = "$($BaseUrl.TrimEnd('/'))/meuportal/api/health"
$anonymousStatus = Get-StatusCode { Invoke-WebRequest -UseBasicParsing -Uri $healthUrl }
Test-Condition ($anonymousStatus -in 401, 403) 'REST API rejects anonymous access.'

if ($Credential) {
    $plainPassword = $Credential.GetNetworkCredential().Password
    $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$plainPassword"))
    $headers = @{ Authorization = "Basic $token"; Accept = 'application/json' }
    $health = Invoke-RestMethod -Uri $healthUrl -Headers $headers
    Test-Condition ($health.data.status -eq 'ok') 'Authenticated health endpoint reports ok.'

    $session = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/meuportal/api/session" -Headers $headers
    Test-Condition ([bool]$session.data.authenticated) 'Authenticated session is recognized by IRIS.'
    Test-Condition ($session.data.accessLevel -in 'Viewer', 'Administrator') 'Authenticated user has a Meu Portal access role.'

    $report = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/meuportal/api/system/health-report" -Headers $headers
    Test-Condition ($report.data.score -ge 0 -and $report.data.score -le 100) 'Embedded Python returns a valid health score.'
    Test-Condition ($report.data.engine -eq 'InterSystems IRIS Embedded Python') 'Health report identifies the Embedded Python engine.'
    Test-Condition (-not [string]::IsNullOrWhiteSpace($report.data.vectorMatch.code)) 'IRIS Vector Search returns a matching health pattern.'
    Test-Condition ($report.data.vectorMatch.similarity -ge 0) 'Vector match includes a similarity score.'
}

if ($failures.Count -gt 0) {
    throw "$($failures.Count) smoke test(s) failed."
}

Write-Host 'All Meu Portal smoke tests passed.' -ForegroundColor Green
