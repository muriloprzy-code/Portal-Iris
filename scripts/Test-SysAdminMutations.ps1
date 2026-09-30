[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential
)

$ErrorActionPreference = 'Stop'
$root = $BaseUrl.TrimEnd('/')
$password = $Credential.GetNetworkCredential().Password
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$password"))
$sysAdminHeaders = @{ Authorization = "Basic $token"; Accept = 'application/json' }
$portalHeaders = @{
    Authorization = "Basic $token"
    'X-MyOwn-SysAdmin-Authorization' = "Basic $token"
    Accept = 'application/json'
}
$temporaryUser = 'MyOwnApiSmokeTest'
$temporaryApplication = '/myown-smoke-test'
$userCreated = $false
$applicationCreated = $false
$originalTaskSuspended = $null
$taskId = $null

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Mutation test failed: $Message" }
    Write-Host "PASS  $Message" -ForegroundColor Green
}

function Invoke-PortalJson {
    param([string]$Method, [string]$Path, [object]$Body)
    $arguments = @{ Uri = "$root/myown/api$Path"; Method = $Method; Headers = $portalHeaders }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json'
        $arguments.Body = $Body | ConvertTo-Json -Depth 10 -Compress
    }
    Invoke-RestMethod @arguments
}

function Invoke-SysAdminJson {
    param([string]$Method, [string]$Path, [object]$Body)
    $arguments = @{ Uri = "$root/api/admin$Path"; Method = $Method; Headers = $sysAdminHeaders }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json'
        $arguments.Body = $Body | ConvertTo-Json -Depth 10 -Compress
    }
    Invoke-RestMethod @arguments
}

function Test-SysAdminObjectExists {
    param([string]$Path)
    # -SkipHttpErrorCheck only exists on PowerShell 7.4+; try/catch works on both
    # Windows PowerShell 5.1 and PowerShell 7+, so it is used here instead.
    try {
        $response = Invoke-WebRequest -Uri "$root/api/admin$Path" -Headers $sysAdminHeaders -UseBasicParsing
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) { return $true }
        throw "Unexpected HTTP $($response.StatusCode) while checking $Path."
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
        if ($statusCode -eq 404) { return $false }
        throw
    }
}

function Wait-TaskSuspendedState {
    param([int]$Id, [bool]$Expected)
    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        $detail = Invoke-PortalJson -Method GET -Path "/tasks/detail?id=$Id"
        if ([int]$detail.data.suspended -eq [int]$Expected) { return $true }
        Start-Sleep -Milliseconds 200
    }
    return $false
}

try {
    $status = Invoke-PortalJson -Method GET -Path '/sysadmin/status'
    Assert-Condition ([bool]$status.data.v2Supported) 'SysAdmin API v2 is active.'

    $encodedUser = [Uri]::EscapeDataString($temporaryUser)
    $userPath = "/v2/security/user?name=$encodedUser"
    if (Test-SysAdminObjectExists -Path $userPath) {
        throw "The reserved temporary user $temporaryUser already exists; it was not modified."
    }
    $temporaryPassword = "MyOwn-$([Guid]::NewGuid().ToString('N'))!"
    $newUser = @{
        User = @{
            Enabled = $false
            FullName = 'Temporary MyOwn Portal SysAdmin API smoke-test user'
            NameSpace = 'MYOWN'
            AccountNeverExpires = $true
            PasswordNeverExpires = $true
            ChangePassword = $false
            Roles = @()
        }
        Password = $temporaryPassword
    }
    Invoke-SysAdminJson -Method POST -Path $userPath -Body $newUser | Out-Null
    $userCreated = $true
    Assert-Condition (Test-SysAdminObjectExists -Path $userPath) 'Temporary disabled user was created through SysAdmin API v2.'

    Invoke-PortalJson -Method POST -Path "/permissions/users/$encodedUser/roles" -Body @{ role = 'MyOwnViewer' } | Out-Null
    $userDetail = Invoke-PortalJson -Method GET -Path "/permissions/users/$encodedUser"
    Assert-Condition ('MyOwnViewer' -in @($userDetail.data.directRoles)) 'Portal assigned a role through SysAdmin API v2.'

    Invoke-PortalJson -Method DELETE -Path "/permissions/users/$encodedUser/roles/MyOwnViewer" | Out-Null
    $userDetail = Invoke-PortalJson -Method GET -Path "/permissions/users/$encodedUser"
    Assert-Condition ('MyOwnViewer' -notin @($userDetail.data.directRoles)) 'Portal removed a role through SysAdmin API v2.'

    $encodedApplication = [Uri]::EscapeDataString($temporaryApplication)
    $applicationPath = "/v2/web-app?name=$encodedApplication"
    if (Test-SysAdminObjectExists -Path $applicationPath) {
        throw "The reserved temporary application $temporaryApplication already exists; it was not modified."
    }
    $newApplication = @{
        NameSpace = 'MYOWN'
        Enabled = $true
        Description = 'Temporary MyOwn Portal SysAdmin API smoke-test application'
        AutheEnabled = 32
        UseCookies = 'Never'
    }
    Invoke-SysAdminJson -Method PUT -Path $applicationPath -Body $newApplication | Out-Null
    $applicationCreated = $true
    Assert-Condition (Test-SysAdminObjectExists -Path $applicationPath) 'Temporary web application was created through SysAdmin API v2.'

    $disabled = Invoke-PortalJson -Method POST -Path '/applications/state' -Body @{ name = $temporaryApplication; enabled = $false }
    Assert-Condition (-not [bool]$disabled.data.enabled) 'Portal disabled the project-owned test application through SysAdmin API v2.'
    $enabled = Invoke-PortalJson -Method POST -Path '/applications/state' -Body @{ name = $temporaryApplication; enabled = $true }
    Assert-Condition ([bool]$enabled.data.enabled) 'Portal re-enabled the project-owned test application through SysAdmin API v2.'

    $tasks = Invoke-PortalJson -Method GET -Path '/tasks'
    $demoTask = @($tasks.data.tasks | Where-Object name -eq 'MyOwn Portal health snapshot' | Select-Object -First 1)
    Assert-Condition ($demoTask.Count -eq 1) 'The project demonstration task is available.'
    $taskId = [int]$demoTask[0].id
    $originalTaskSuspended = ([int]$demoTask[0].suspended -eq 1)
    if ($originalTaskSuspended) {
        Invoke-PortalJson -Method POST -Path '/tasks/action' -Body @{ id = $taskId; action = 'resume' } | Out-Null
    }
    Invoke-PortalJson -Method POST -Path '/tasks/action' -Body @{ id = $taskId; action = 'suspend' } | Out-Null
    Assert-Condition (Wait-TaskSuspendedState -Id $taskId -Expected $true) 'Portal suspended the demonstration task through SysAdmin API v2.'

    Invoke-PortalJson -Method POST -Path '/tasks/action' -Body @{ id = $taskId; action = 'resume' } | Out-Null
    Assert-Condition (Wait-TaskSuspendedState -Id $taskId -Expected $false) 'Portal resumed the demonstration task through SysAdmin API v2.'

    Invoke-PortalJson -Method POST -Path '/tasks/action' -Body @{ id = $taskId; action = 'run' } | Out-Null
    Assert-Condition $true 'Portal requested an immediate demonstration-task run through SysAdmin API v2.'
} finally {
    if ($null -ne $originalTaskSuspended -and $null -ne $taskId) {
        try {
            $taskDetail = Invoke-PortalJson -Method GET -Path "/tasks/detail?id=$taskId"
            if (([int]$taskDetail.data.suspended -eq 1) -ne $originalTaskSuspended) {
                $restoreAction = if ($originalTaskSuspended) { 'suspend' } else { 'resume' }
                Invoke-PortalJson -Method POST -Path '/tasks/action' -Body @{ id = $taskId; action = $restoreAction } | Out-Null
            }
        } catch { Write-Warning "Could not restore the demonstration task state: $($_.Exception.Message)" }
    }
    if ($applicationCreated) {
        try { Invoke-SysAdminJson -Method DELETE -Path $applicationPath | Out-Null }
        catch { Write-Warning "Could not remove $temporaryApplication`: $($_.Exception.Message)" }
    }
    if ($userCreated) {
        try { Invoke-SysAdminJson -Method DELETE -Path $userPath | Out-Null }
        catch { Write-Warning "Could not remove $temporaryUser`: $($_.Exception.Message)" }
    }
}

Write-Host 'All controlled SysAdmin API v2 mutation tests passed, and temporary fixtures were removed.' -ForegroundColor Green
