[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52773',
    [PSCredential]$Credential,
    [ValidateSet('iris', 'irisforhealth')]
    [string]$ExpectedProduct
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

$portalUrl = "$($BaseUrl.TrimEnd('/'))/myown/index.html"
$portal = Invoke-WebRequest -UseBasicParsing -Uri $portalUrl -MaximumRedirection 5
Test-Condition ($portal.StatusCode -eq 200) 'Production portal returns HTTP 200.'
Test-Condition ($portal.Content -match '<div id="root"></div>') 'Production HTML contains the React root element.'

$assetMatches = [regex]::Matches($portal.Content, '(?:src|href)="(?<path>/myown/assets/[^"]+)"')
Test-Condition ($assetMatches.Count -ge 2) 'Production HTML references compiled JavaScript and CSS assets.'
foreach ($match in $assetMatches) {
    $assetUrl = "$($BaseUrl.TrimEnd('/'))$($match.Groups['path'].Value)"
    $asset = Invoke-WebRequest -UseBasicParsing -Uri $assetUrl
    Test-Condition ($asset.StatusCode -eq 200 -and $asset.RawContentLength -gt 0) "Asset is available: $($match.Groups['path'].Value)"
}

$healthUrl = "$($BaseUrl.TrimEnd('/'))/myown/api/health"
$anonymousStatus = Get-StatusCode { Invoke-WebRequest -UseBasicParsing -Uri $healthUrl }
Test-Condition ($anonymousStatus -in 401, 403) 'REST API rejects anonymous access.'

if ($Credential) {
    $plainPassword = $Credential.GetNetworkCredential().Password
    $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$plainPassword"))
    $headers = @{
        Authorization = "Basic $token"
        'X-MyOwn-SysAdmin-Authorization' = "Basic $token"
        Accept = 'application/json'
    }
    $health = Invoke-RestMethod -Uri $healthUrl -Headers $headers
    Test-Condition ($health.data.status -eq 'ok') 'Authenticated health endpoint reports ok.'

    $session = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/session" -Headers $headers
    Test-Condition ([bool]$session.data.authenticated) 'Authenticated session is recognized by IRIS.'
    Test-Condition ($session.data.accessLevel -in 'Viewer', 'Administrator') 'Authenticated user has a MyOwn Portal access role.'

    $sysAdmin = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/sysadmin/status" -Headers $headers
    Test-Condition ([int]$sysAdmin.data.apiVersion -ge 2) 'The local IRIS SysAdmin API v2 capability endpoint is available.'
    Test-Condition ([bool]$sysAdmin.data.v2Supported) 'The portal confirms SysAdmin API v2 is supported.'
    Test-Condition ($sysAdmin.data.mode -eq 'sysadmin-v2') 'The portal reports SysAdmin API v2 as its integration mode.'
    if ($ExpectedProduct) {
        Test-Condition ($sysAdmin.data.product -eq $ExpectedProduct) "The tested instance reports product '$ExpectedProduct'."
    }

    $processes = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/system/processes" -Headers $headers
    $expectedProcessSource = 'sysadmin-v2'
    Test-Condition ($processes.meta.source -eq $expectedProcessSource) 'The process inventory reports the expected data source.'

    $permissionUsers = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/permissions/users" -Headers $headers
    $permissionRoles = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/permissions/roles" -Headers $headers
    $permissionResources = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/permissions/resources" -Headers $headers
    Test-Condition ($permissionUsers.meta.source -eq $expectedProcessSource) 'The user inventory reports the expected data source.'
    Test-Condition ($permissionRoles.meta.source -eq $expectedProcessSource) 'The role inventory reports the expected data source.'
    Test-Condition ($permissionResources.meta.source -eq $expectedProcessSource) 'The resource inventory reports the expected data source.'
    Test-Condition (@($permissionUsers.data | Where-Object { [int]$_.enabled -eq 1 }).Count -gt 0) 'The user inventory includes enabled users.'

    $systemUser = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/permissions/users/_SYSTEM" -Headers $headers
    Test-Condition ([int]$systemUser.data.enabled -eq 1) 'The _SYSTEM user is reported as enabled.'
    Test-Condition ('%All' -in @($systemUser.data.directRoles)) 'The _SYSTEM user includes the %All role.'

    $administratorRole = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/permissions/roles/MyOwnAdministrator" -Headers $headers
    $administratorResources = @($administratorRole.data.permissions | ForEach-Object { $_.resource })
    foreach ($requiredResource in @('%Admin_Operate', '%Admin_Secure', '%Admin_Task', '%Admin_Wallet', '%Admin_OAuth2_Client', '%Admin_OAuth2_Server', '%Admin_OAuth2_Registration')) {
        Test-Condition ($requiredResource -in $administratorResources) "MyOwnAdministrator includes $requiredResource."
    }

    $tasks = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/tasks" -Headers $headers
    Test-Condition ($tasks.meta.source -eq $expectedProcessSource) 'The task inventory reports the expected data source.'
    Test-Condition (@($tasks.data.tasks).Count -gt 0) 'The task inventory contains native IRIS tasks.'

    $applications = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/applications" -Headers $headers
    Test-Condition ($applications.meta.source -eq $expectedProcessSource) 'The web application inventory reports the expected data source.'
    Test-Condition (@($applications.data).Count -gt 0) 'The web application inventory is not empty.'
    $portalApiApplication = @($applications.data | Where-Object { $_.name -eq '/myown/api' }) | Select-Object -First 1
    Test-Condition ($null -ne $portalApiApplication) 'The web application inventory includes /myown/api.'
    Test-Condition ([int]$portalApiApplication.enabled -eq 1) 'The /myown/api web application is reported as enabled.'

    $security = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/security" -Headers $headers
    Test-Condition ($security.meta.source -eq $expectedProcessSource) 'The security inventory reports the expected data source.'
    Test-Condition ($null -ne $security.data.errors) 'The security inventory reports category-level availability.'

    $report = Invoke-RestMethod -Uri "$($BaseUrl.TrimEnd('/'))/myown/api/system/health-report" -Headers $headers
    Test-Condition ($report.data.score -ge 0 -and $report.data.score -le 100) 'Embedded Python returns a valid health score.'
    Test-Condition ($report.data.engine -eq 'InterSystems IRIS Embedded Python') 'Health report identifies the Embedded Python engine.'
    Test-Condition (-not [string]::IsNullOrWhiteSpace($report.data.vectorMatch.code)) 'IRIS Vector Search returns a matching health pattern.'
    Test-Condition ($report.data.vectorMatch.similarity -ge 0) 'Vector match includes a similarity score.'
}

if ($failures.Count -gt 0) {
    throw "$($failures.Count) smoke test(s) failed."
}

Write-Host 'All MyOwn Portal smoke tests passed.' -ForegroundColor Green
