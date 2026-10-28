/// Authenticated REST entry point for the MyOwn Portal administration interface: system, security,
/// tasks and logs, and the AI agent (decisions, proposals, access requests, ledger, production).
Class MyOwn.REST Extends MyOwn.REST.Docs
{

Parameter DOCSTITLE = "MyOwn Portal API";

Parameter DOCSVERSION = "1.1.0";

/// The React frontend is served from the same origin (or through the Vite proxy
/// during development), so cross-origin requests are deliberately not accepted.
Parameter HandleCorsRequest = 0;

Parameter UseSession = 1;

XData UrlMap
{
<Routes>
  <Route Url="/health" Method="GET" Call="Health" />
  <Route Url="/session" Method="GET" Call="CurrentSession" />
  <Route Url="/sysadmin/status" Method="GET" Call="SysAdminStatus" />
  <Route Url="/system/summary" Method="GET" Call="SystemSummary" />
  <Route Url="/system/health-report" Method="GET" Call="SystemHealthReport" />
  <Route Url="/system/processes" Method="GET" Call="SystemProcesses" />
  <Route Url="/permissions/users" Method="GET" Call="PermissionUsers" />
  <Route Url="/permissions/roles" Method="GET" Call="PermissionRoles" />
  <Route Url="/permissions/resources" Method="GET" Call="PermissionResources" />
  <Route Url="/permissions/users/:user/effective" Method="GET" Call="PermissionUserEffective" />
  <Route Url="/permissions/users/:user/roles" Method="POST" Call="AddPermissionUserRole" />
  <Route Url="/permissions/users/:user/roles/:role" Method="DELETE" Call="RemovePermissionUserRole" />
  <Route Url="/permissions/users/:user" Method="GET" Call="PermissionUserDetail" />
  <Route Url="/permissions/roles/:role" Method="GET" Call="PermissionRoleDetail" />
  <Route Url="/applications" Method="GET" Call="Applications" />
  <Route Url="/applications/detail" Method="GET" Call="ApplicationDetail" />
  <Route Url="/applications/state" Method="POST" Call="SetApplicationState" />
  <Route Url="/apis/test" Method="POST" Call="TestAPI" />
  <Route Url="/openapi" Method="GET" Call="OpenAPI" />
  <Route Url="/security" Method="GET" Call="Security" />
  <Route Url="/security/summary" Method="GET" Call="SecuritySummary" />
  <Route Url="/security/certificates" Method="GET" Call="SecurityCertificates" />
  <Route Url="/security/oauth" Method="GET" Call="SecurityOAuth" />
  <Route Url="/security/credentials" Method="GET" Call="SecurityCredentials" />
  <Route Url="/security/detail" Method="GET" Call="SecurityDetail" />
  <Route Url="/tasks" Method="GET" Call="Tasks" />
  <Route Url="/tasks/detail" Method="GET" Call="TaskDetail" />
  <Route Url="/tasks/action" Method="POST" Call="TaskAction" />
  <Route Url="/logs" Method="GET" Call="Logs" />
  <Route Url="/agent/status" Method="GET" Call="AgentStatus" />
  <Route Url="/agent/config" Method="GET" Call="AgentConfig" />
  <Route Url="/agent/config" Method="PUT" Call="UpdateAgentConfig" />
  <Route Url="/agent/killswitch" Method="POST" Call="SetAgentKillSwitch" />
  <Route Url="/agent/decisions" Method="GET" Call="AgentDecisions" />
  <Route Url="/agent/decisions/:id" Method="GET" Call="AgentDecisionDetail" />
  <Route Url="/agent/proposals" Method="GET" Call="AgentProposals" />
  <Route Url="/agent/proposals/:id/confirm" Method="POST" Call="ConfirmAgentProposal" />
  <Route Url="/agent/proposals/:id/reject" Method="POST" Call="RejectAgentProposal" />
  <Route Url="/agent/access-requests" Method="POST" Call="SubmitAgentAccessRequest" />
  <Route Url="/agent/access-requests" Method="GET" Call="AgentAccessRequests" />
  <Route Url="/agent/access-requests/:id" Method="GET" Call="AgentAccessRequestDetail" />
  <Route Url="/agent/ledger/summary" Method="GET" Call="AgentLedgerSummary" />
  <Route Url="/agent/ledger" Method="GET" Call="AgentLedger" />
  <Route Url="/agent/traces/:traceId" Method="GET" Call="AgentTrace" />
  <Route Url="/agent/pricing" Method="GET" Call="AgentPricing" />
  <Route Url="/agent/pricing" Method="PUT" Call="UpdateAgentPricing" />
  <Route Url="/agent/production/status" Method="GET" Call="AgentProductionStatus" />
  <Route Url="/agent/production/start" Method="POST" Call="StartAgentProduction" />
  <Route Url="/agent/production/stop" Method="POST" Call="StopAgentProduction" />
  <Route Url="/agent/guardrails" Method="GET" Call="AgentGuardrails" />
  <Route Url="/agent/simulate" Method="POST" Call="SimulateAgentScenario" />
  <Route Url="/agent/analyze" Method="POST" Call="AnalyzeWithAgent" />
  <Route Url="/demo/state" Method="GET" Call="DemoState" />
  <Route Url="/demo/reset" Method="POST" Call="DemoReset" />
</Routes>
}

/// Checks that the API answers and returns the instance name and IRIS version.
ClassMethod Health() As %Status
{
    Set tSC = $$$OK
    Set payload = {}
    Set payload.data = {}
    Set payload.data.status = "ok"
    Set payload.data.application = "MyOwn Portal"
    Set payload.data.instance = ##class(%SYS.System).GetInstanceName()
    Set payload.data.version = $ZVersion
    Set payload.meta = {}
    Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)

    Set %response.ContentType = "application/json; charset=utf-8"
    Write payload.%ToJSON()
    Quit tSC
}

/// The signed-in account: name, access level (Viewer or Administrator) and what the portal lets it do.
ClassMethod CurrentSession() As %Status
{
    Set tSC = $$$OK
    Set tSC = ##class(MyOwn.Service.Access).Current(.access)
    Set payload = {}
    Set payload.data = {}
    Set payload.data.authenticated = ($Username '= "")
    Set payload.data.username = $Username
    Set payload.data.accessLevel = access.level
    Set payload.data.canView = access.canView
    Set payload.data.canManage = access.canManage
    Set payload.data.demoMode = ##class(MyOwn.Demo.Mode).Enabled()
    Set payload.data.isDemoUser = payload.data.demoMode && ##class(MyOwn.Demo.Mode).IsDemoUser()
    Set payload.meta = {}
    Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)

    Set %response.ContentType = "application/json; charset=utf-8"
    Write payload.%ToJSON()
    Quit tSC
}

/// IRIS system summary: version, uptime, memory, disk, database space, lock table and process counts.
ClassMethod SystemSummary() As %Status
{
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set tSC = ##class(MyOwn.Service.System).GetSummary(.data)
        $$$ThrowOnError(tSC)
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
        Set %response.Status = 500
        Set payload = {}
        Set payload.error = {}
        Set payload.error.code = "SYSTEM_SUMMARY_UNAVAILABLE"
        Set payload.error.message = "System metrics are temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

/// Active IRIS processes (at most 25) (administrator).
ClassMethod SystemProcesses() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set authorization = ..GetForwardedAuthorization()
        Set tSC = ##class(MyOwn.Service.System).GetProcesses(authorization, .data, .source)
        $$$ThrowOnError(tSC)
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set payload.meta.limit = 25
        Set payload.meta.source = source
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
        Set %response.Status = 500
        Set payload = {}
        Set payload.error = {}
        Set payload.error.code = "PROCESS_LIST_UNAVAILABLE"
        Set payload.error.message = "The process list is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

/// Confirms that this IRIS instance provides the required SysAdmin API v2 (administrator).
ClassMethod SysAdminStatus() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.SysAdminClient).RequireV2(authorization, .info)
    If $$$ISERR(tSC) Quit ..WriteError(502, "SYSADMIN_API_V2_REQUIRED", "The local IRIS SysAdmin API v2 is unavailable or incompatible.")

    Set data = {}
    Set data.available = 1
    Set data.apiVersion = info.%Get("apiVersion")
    Set data.serverVersion = info.%Get("serverVersion")
    Set data.product = info.%Get("product")
    Set data.v2Supported = 1
    Set data.mode = "sysadmin-v2"
    Quit ..WriteSuccess(data)
}

/// Health report: an Embedded Python score, the anomalies against recent history and the closest known health pattern (Vector Search).
ClassMethod SystemHealthReport() As %Status
{
    Set tSC = ##class(MyOwn.Service.HealthAnalysis).GetReport(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "HEALTH_REPORT_UNAVAILABLE", "The instance health report is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// IRIS users (names, roles, enabled), read through SysAdmin API v2 with the caller's credentials (administrator).
ClassMethod PermissionUsers() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("users")
}

/// IRIS roles and their resources (administrator).
ClassMethod PermissionRoles() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("roles")
}

/// IRIS resources and their public permissions (administrator).
ClassMethod PermissionResources() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("resources")
}

/// One IRIS user: roles, state and login settings (administrator).
ClassMethod PermissionUserDetail(user As %String) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Permissions).GetUserDetail(user, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "USER_NOT_FOUND", "The requested user could not be found.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// Effective privileges of one user: roles and the resources they grant (administrator).
ClassMethod PermissionUserEffective(user As %String) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Permissions).GetUserDetail(user, authorization, .detail, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "USER_NOT_FOUND", "The requested user could not be found.")
    Set data = {}
    Set data.user = detail.name
    Set data.roles = detail.effectiveRoles
    Set data.permissions = detail.effectivePermissions
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// One IRIS role: resources and members (administrator).
ClassMethod PermissionRoleDetail(role As %String) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Permissions).GetRoleDetail(role, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "ROLE_NOT_FOUND", "The requested role could not be found.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// Adds a role to a user through SysAdmin API v2 (administrator; refused in demo mode).
ClassMethod AddPermissionUserRole(user As %String) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    If '##class(MyOwn.Service.Permissions).CanManage() Quit ..WriteError(403, "FORBIDDEN", "You do not have permission to manage user roles.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        Set role = body.%Get("role")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_JSON", "A valid JSON body is required.")
    If role = "" Quit ..WriteError(400, "ROLE_REQUIRED", "The role field is required.")
    If role = "%All" Quit ..WriteError(400, "PROTECTED_ROLE", "The %All role cannot be changed through MyOwn Portal.")

    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Permissions).AddUserRole(user, role, authorization, .data, .source)
    Do ##class(MyOwn.Service.Audit).Record("AssignRole", user _ "/" _ role, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "ROLE_ASSIGNMENT_FAILED", "The role could not be assigned to this user.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// Removes a role from a user through SysAdmin API v2 (administrator; refused in demo mode).
ClassMethod RemovePermissionUserRole(user As %String, role As %String) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    If '##class(MyOwn.Service.Permissions).CanManage() Quit ..WriteError(403, "FORBIDDEN", "You do not have permission to manage user roles.")
    If role = "%All" Quit ..WriteError(400, "PROTECTED_ROLE", "The %All role cannot be changed through MyOwn Portal.")

    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Permissions).RemoveUserRole(user, role, authorization, .data, .source)
    Do ##class(MyOwn.Service.Audit).Record("RemoveRole", user _ "/" _ role, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "ROLE_REMOVAL_FAILED", "The role could not be removed from this user.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// IRIS web applications (path, namespace, enabled, authentication methods) (administrator).
ClassMethod Applications() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set authorization = ..GetForwardedAuthorization()
        Set tSC = ##class(MyOwn.Service.Applications).GetApplications(authorization, .data, .source)
        $$$ThrowOnError(tSC)
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set payload.meta.source = source
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
        Set %response.Status = 500
        Set payload = {}
        Set payload.error = {}
        Set payload.error.code = "APPLICATIONS_UNAVAILABLE"
        Set payload.error.message = "The web application inventory is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

/// One web application, selected by name (administrator).
ClassMethod ApplicationDetail() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set application = $Get(%request.Data("name", 1))
    If application = "" Quit ..WriteError(400, "APPLICATION_REQUIRED", "The application name is required.")

    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Applications).GetApplication(application, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "APPLICATION_NOT_FOUND", "The requested web application could not be found.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// Enables or disables a web application (administrator; refused in demo mode).
ClassMethod SetApplicationState() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    If '##class(MyOwn.Service.Applications).CanManage() Quit ..WriteError(403, "FORBIDDEN", "You do not have permission to manage web applications.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        Set application = body.%Get("name")
        Set enabled = body.%Get("enabled")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_JSON", "A valid JSON body is required.")
    If application = "" Quit ..WriteError(400, "APPLICATION_REQUIRED", "The application name is required.")

    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Applications).GetApplication(application, authorization, .detail, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "APPLICATION_NOT_FOUND", "The requested web application could not be found.")
    If 'detail.manageable Quit ..WriteError(400, "PROTECTED_APPLICATION", detail.protectionReason)

    Set tSC = ##class(MyOwn.Service.Applications).SetApplicationEnabled(application, enabled, authorization, .data, .source)
    Do ##class(MyOwn.Service.Audit).Record($Select(enabled:"EnableApplication", 1:"DisableApplication"), application, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "APPLICATION_UPDATE_FAILED", "The web application state could not be changed.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// Runs one bounded request against a local /myown/api or /api path, after an explicit confirmation for state-changing methods (administrator; refused in demo mode).
ClassMethod TestAPI() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set parseError = 0
    Try {
        Set requestBody = {}.%FromJSON(%request.Content)
        Set method = requestBody.%Get("method")
        Set path = requestBody.%Get("path")
        Set headers = requestBody.%Get("headers")
        Set body = requestBody.%Get("body")
        Set confirmed = requestBody.%Get("confirmed")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_JSON", "A valid JSON body is required.")
    Set normalizedMethod = $ZConvert(method, "U")
    If (normalizedMethod '= "GET") && (normalizedMethod '= "HEAD") && ('confirmed) Quit ..WriteError(400, "CONFIRMATION_REQUIRED", "State-changing API tests require confirmation.")

    Set authorization = ..GetForwardedAuthorization()
    ; SERVER_PORT reflects the port the browser used (e.g. Docker's published
    ; 52774), not the port IRIS's private web server actually listens on
    ; inside the container (52773) -- using it here made every API Explorer
    ; request fail with "unable to open TCP/IP socket to 127.0.0.1:<external
    ; port>". This call always targets IRIS's own private web server, so it
    ; always uses that fixed, well-known port instead of trusting SERVER_PORT.
    Set port = 52773
    Set tSC = ##class(MyOwn.Service.APIExplorer).Execute(method, path, headers, body, authorization, port, .data)
    If (normalizedMethod '= "GET") && (normalizedMethod '= "HEAD") Do ##class(MyOwn.Service.Audit).Record("APIRequest" _ normalizedMethod, path, $$$ISOK(tSC))
    If $$$ISERR(tSC) {
        Set detail = $System.Status.GetErrorText(tSC)
        Quit ..WriteError(400, "API_REQUEST_REJECTED", "The request was rejected or could not be completed: " _ detail)
    }
    Quit ..WriteSuccess(data)
}

/// The OpenAPI document of this API (same content as /openapi.json, kept for the API explorer).
ClassMethod OpenAPI() As %Status
{
    Quit ..WriteOpenAPI()
}


/// Scheduled tasks of the instance (name, namespace, schedule, last run, suspended) (administrator).
ClassMethod Tasks() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set authorization = ..GetForwardedAuthorization()
        Set tSC = ##class(MyOwn.Service.Tasks).GetTasks(authorization, .data, .source)
        $$$ThrowOnError(tSC)
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set payload.meta.source = source
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
        Set %response.Status = 500
        Set payload = {}
        Set payload.error = {}
        Set payload.error.code = "TASKS_UNAVAILABLE"
        Set payload.error.message = "The task inventory is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

/// One scheduled task, selected by id (administrator).
ClassMethod TaskDetail() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set id = +$Get(%request.Data("id", 1))
    If id < 1 Quit ..WriteError(400, "TASK_REQUIRED", "A valid task ID is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Tasks).GetTask(id, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "TASK_NOT_FOUND", "The requested task could not be found.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// Runs, suspends or resumes a task (JSON body: id and action); refused in demo mode (administrator).
ClassMethod TaskAction() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        Set id = +body.%Get("id")
        Set action = body.%Get("action")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_JSON", "A valid JSON body is required.")
    If id < 1 Quit ..WriteError(400, "TASK_REQUIRED", "A valid task ID is required.")
    If (action '= "run") && (action '= "suspend") && (action '= "resume") Quit ..WriteError(400, "INVALID_ACTION", "Use run, suspend, or resume.")

    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Tasks).GetTask(id, authorization, .detail, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "TASK_NOT_FOUND", "The requested task could not be found.")
    If 'detail.manageable Quit ..WriteError(403, "PROTECTED_TASK", detail.protectionReason)

    Set tSC = ##class(MyOwn.Service.Tasks).PerformAction(id, action, authorization, .data, .source)
    Do ##class(MyOwn.Service.Audit).Record("Task" _ $ZConvert(action, "T"), "Task " _ id, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "TASK_ACTION_FAILED", "The task action could not be completed.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// Security inventory (users, roles, applications, certificates, OAuth and credentials), without secrets (administrator).
ClassMethod Security() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set authorization = ..GetForwardedAuthorization()
        Set tSC = ##class(MyOwn.Service.Security).GetInventory(authorization, .data, .source)
        $$$ThrowOnError(tSC)
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set payload.meta.source = source
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
        Set %response.Status = 500
        Set payload = {}
        Set payload.error = {}
        Set payload.error.code = "SECURITY_INVENTORY_UNAVAILABLE"
        Set payload.error.message = "The security inventory is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

/// Counts for the security overview (administrator).
ClassMethod SecuritySummary() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Security).GetSummary(authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(500, "SECURITY_SUMMARY_UNAVAILABLE", "The security summary is temporarily unavailable.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

/// TLS configurations and certificates, without private keys (administrator).
ClassMethod SecurityCertificates() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("certificates")
}

/// OAuth 2.0 client and server definitions, without secrets (administrator).
ClassMethod SecurityOAuth() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("oauth")
}

/// Interoperability credentials by name; passwords are never returned (administrator).
ClassMethod SecurityCredentials() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("credentials")
}

/// One security item, selected by category and name, without secrets (administrator).
ClassMethod SecurityDetail() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set category = $Get(%request.Data("category", 1))
    Set name = $Get(%request.Data("name", 1))
    Set type = $Get(%request.Data("type", 1))
    If (category = "") || (name = "") Quit ..WriteError(400, "SECURITY_ITEM_REQUIRED", "The security category and item name are required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Security).GetDetail(category, name, type, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "SECURITY_ITEM_NOT_FOUND", "The requested security item could not be found.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

ClassMethod WriteSecurityCategory(category As %String) As %Status
{
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Security).GetCategory(category, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(500, "SECURITY_CATEGORY_UNAVAILABLE", "The requested security inventory is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Recent IRIS log events (messages.log and alerts), sanitized.
ClassMethod Logs() As %Status
{
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set tSC = ##class(MyOwn.Service.Logs).GetLogs(.data)
        $$$ThrowOnError(tSC)
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
        Set %response.Status = 500
        Set payload = {}
        Set payload.error = {}
        Set payload.error.code = "LOGS_UNAVAILABLE"
        Set payload.error.message = "The system log is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

/// Agent subsystem status: active engine, provider and model names, AI mode, deadline, whether a key is configured (never the key), kill switch.
ClassMethod AgentStatus() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Status(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_STATUS_UNAVAILABLE", "The agent status is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Agent settings (engine preference, autonomy, budgets, cooldown); administrator only.
ClassMethod AgentConfig() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Config).PublicView(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_CONFIG_UNAVAILABLE", "The agent configuration is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Updates the agent settings; every change is audited (administrator).
ClassMethod UpdateAgentConfig() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_REQUEST", "A valid JSON body is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).UpdateConfig(body, $Username, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "AGENT_CONFIG_UPDATE_FAILED", "The agent configuration could not be updated.")
    Quit ..WriteSuccess(data)
}

/// Turns the kill switch on or off: with it on, the agent makes no AI call and proposes nothing (administrator).
ClassMethod SetAgentKillSwitch() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        If 'body.%IsDefined("enabled") Set parseError = 1
        If 'parseError Set enabled = +body.%Get("enabled")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_REQUEST", "A JSON body with enabled is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).SetKillSwitch(enabled, $Username, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "AGENT_KILLSWITCH_FAILED", "The agent kill switch could not be changed.")
    Quit ..WriteSuccess(data)
}

/// Recent agent decisions with their engine, outcome and fallback reason.
ClassMethod AgentDecisions() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListDecisions(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_DECISIONS_UNAVAILABLE", "Agent decisions are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// One decision: rationale, evidence, conditions, Gate result, proposal and the model text as plain text.
ClassMethod AgentDecisionDetail(id As %Integer) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).DecisionDetail(id, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "DECISION_NOT_FOUND", "The requested decision was not found.")
    Quit ..WriteSuccess(data)
}

/// Proposals waiting for a human, and their state.
ClassMethod AgentProposals() As %Status
{
    If '..CanOperateProposals() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set state = $Get(%request.Data("state", 1))
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListProposals(state, .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_PROPOSALS_UNAVAILABLE", "Agent proposals are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Confirms a pending proposal: state, expiry, separation of duties, prohibited targets, target fingerprint and live permission are checked again, then the change runs with the confirming user's credentials and is read back.
ClassMethod ConfirmAgentProposal(id As %Integer) As %Status
{
    If '..CanOperateProposals() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(id, $Username, ..GetForwardedAuthorization(), .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "PROPOSAL_CONFIRM_FAILED", "The proposal could not be confirmed.")
    Quit ..WriteSuccess(data)
}

/// Rejects a pending proposal; the rejection is audited.
ClassMethod RejectAgentProposal(id As %Integer) As %Status
{
    If '..CanOperateProposals() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set parseError = 0
    Set reason = ""
    If %request.Content '= "" {
        Try {
            Set body = {}.%FromJSON(%request.Content)
            Set reason = body.%Get("reason")
        } Catch exception {
            Set parseError = 1
        }
    }
    If parseError Quit ..WriteError(400, "INVALID_REQUEST", "A valid JSON body is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).RejectProposal(id, $Username, reason, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "PROPOSAL_REJECT_FAILED", "The proposal could not be rejected.")
    Quit ..WriteSuccess(data)
}

/// Queues an access request (role and justification) for asynchronous agent analysis.
ClassMethod SubmitAgentAccessRequest() As %Status
{
    ; The privilege delta is read through SysAdmin API v2 with the requester's own credentials,
    ; which needs %Admin_Secure even for one's own account: say so instead of failing with 500.
    If '$System.Security.Check("%Admin_Secure", "USE") Quit ..WriteError(403, "ACCESS_REQUEST_NEEDS_SECURITY_READ", "Filing an access request reads your own privileges through the SysAdmin API, which requires %Admin_Secure:USE. Ask an administrator to file it.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        Set role = body.%Get("role")
        Set justification = body.%Get("justification")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_REQUEST", "A valid JSON body is required.")
    Try {
        Set tSC = ##class(MyOwn.Agent.Service.Agent).SubmitAccessRequest(role, justification, ..GetForwardedAuthorization(), $Username, .data)
    } Catch exception {
        ; Never let an internal error location reach the client.
        Set tSC = $$$ERROR($$$GeneralError, "ACCESS_REQUEST_FAILED")
    }
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "ACCESS_REQUEST_FAILED", "The access request could not be submitted.")
    Quit ..WriteSuccess(data)
}

/// Access requests visible to the current user.
ClassMethod AgentAccessRequests() As %Status
{
    Set includeAll = ##class(MyOwn.Service.Access).CanManage()
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListAccessRequests($Username, includeAll, .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "ACCESS_REQUESTS_UNAVAILABLE", "Access requests are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// One access request and its decision.
ClassMethod AgentAccessRequestDetail(id As %Integer) As %Status
{
    Set includeAll = ##class(MyOwn.Service.Access).CanManage()
    Set tSC = ##class(MyOwn.Agent.Service.Agent).AccessRequestDetail(id, $Username, includeAll, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "ACCESS_REQUEST_NOT_FOUND", "The requested access request was not found.")
    Quit ..WriteSuccess(data)
}

/// Observability totals: decisions, AI calls, tokens and estimated cost.
ClassMethod AgentLedgerSummary() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).LedgerSummary(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_LEDGER_UNAVAILABLE", "Agent observability data is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Execution ledger entries: engine, provider, model, latency, tokens and outcome per decision (administrator).
ClassMethod AgentLedger() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListLedger(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_LEDGER_UNAVAILABLE", "Agent observability data is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// End-to-end trace of one event through the production: messages, decision, Gate and proposal.
ClassMethod AgentTrace(traceId As %String) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Trace(traceId, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "AGENT_TRACE_UNAVAILABLE", "The requested trace could not be loaded.")
    Quit ..WriteSuccess(data)
}

/// Configured model prices used for cost estimates (administrator).
ClassMethod AgentPricing() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListPricing(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_PRICING_UNAVAILABLE", "Agent pricing is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Updates the model prices (administrator).
ClassMethod UpdateAgentPricing() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_REQUEST", "A valid JSON body is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).SavePricing(body, $Username, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "AGENT_PRICING_UPDATE_FAILED", "Agent pricing could not be updated.")
    Quit ..WriteSuccess(data)
}

/// State of the agent interoperability production and its items.
ClassMethod AgentProductionStatus() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ProductionStatus(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "PRODUCTION_STATUS_UNAVAILABLE", "The agent production status is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Starts the agent production (administrator).
ClassMethod StartAgentProduction() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ControlProduction("start", .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "PRODUCTION_START_FAILED", "The agent production could not be started.")
    Set auditStatus = ##class(MyOwn.Service.Audit).Record("AgentProductionStart", "MyOwn.Production.Main", 1)
    Quit ..WriteSuccess(data)
}

/// Stops the agent production (administrator).
ClassMethod StopAgentProduction() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ControlProduction("stop", .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "PRODUCTION_STOP_FAILED", "The agent production could not be stopped.")
    Set auditStatus = ##class(MyOwn.Service.Audit).Record("AgentProductionStop", "MyOwn.Production.Main", 1)
    Quit ..WriteSuccess(data)
}

/// The guardrails in force: hard rules, prohibited targets, prompts and the data sent to the model.
ClassMethod AgentGuardrails() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Guardrails(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "GUARDRAILS_UNAVAILABLE", "Agent guardrails are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

/// Runs a demonstration scenario (S1 to S10) through the interoperability production; needs demo scenarios enabled.
ClassMethod SimulateAgentScenario() As %Status
{
    Set demo = ##class(MyOwn.Demo.Mode).Enabled()
    If '##class(MyOwn.Service.Access).CanManage() && '(demo && ##class(MyOwn.Demo.Mode).IsDemoUser()) Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_CONFIG_UNAVAILABLE", "The agent configuration is temporarily unavailable.")
    If 'config.DemoMode && 'demo Quit ..WriteError(403, "AGENT_DISABLED", "Demonstration scenarios are disabled.")
    If demo && '..DemoRateAllowed(.retryAfter) {
        Set %response.Headers("Retry-After") = retryAfter
        Quit ..WriteError(429, "RATE_LIMITED", "Too many demonstration scenarios; try again in a minute.")
    }
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        Set scenario = body.%Get("scenario")
        Set taskId = +body.%Get("taskId")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_REQUEST", "A valid JSON body is required.")
    Set tSC = ##class(MyOwn.Install.Scenarios).Run(scenario, ..GetForwardedAuthorization(), taskId, $Username, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "SIMULATION_FAILED", "The requested scenario could not be simulated.")
    Quit ..WriteSuccess(data)
}

/// Sends one incident context to the agent through the production and returns the decision (administrator).
ClassMethod AnalyzeWithAgent() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Context.Health).Current(.context)
    If $$$ISERR(tSC) Quit ..WriteError(500, "HEALTH_REPORT_UNAVAILABLE", "The current health context is temporarily unavailable.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Analyze("incident-triage", context.%ToJSON(), "manual", "", $Username, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "AGENT_ANALYSIS_FAILED", "The current instance health could not be analyzed.")
    Quit ..WriteSuccess(data)
}

ClassMethod WriteAgentError(tSC As %Status, defaultCode As %String, defaultMessage As %String) As %Status [ Private ]
{
    Set text = $System.Status.GetErrorText(tSC)
    If text [ "PROPOSAL_NOT_FOUND" Quit ..WriteError(404, "PROPOSAL_NOT_FOUND", "The requested proposal was not found.")
    If text [ "PROPOSAL_EXPIRED" Quit ..WriteError(409, "PROPOSAL_EXPIRED", "The proposal has expired.")
    If text [ "PROPOSAL_ALREADY_RESOLVED" Quit ..WriteError(409, "PROPOSAL_ALREADY_RESOLVED", "The proposal has already been resolved.")
    If text [ "PROPOSAL_BUSY" Quit ..WriteError(409, "PROPOSAL_BUSY", "The proposal is being processed by another request.")
    If text [ "TARGET_CHANGED" Quit ..WriteError(409, "TARGET_CHANGED", "The target changed after the proposal was created.")
    If text [ "EXECUTION_READBACK_FAILED" Quit ..WriteError(500, "EXECUTION_READBACK_FAILED", "The requested change could not be verified after execution.")
    If text [ "SEPARATION_OF_DUTIES" Quit ..WriteError(403, "SEPARATION_OF_DUTIES", "The requester cannot confirm the same access request.")
    If text [ "PROHIBITED_TARGET" Quit ..WriteError(403, "PROHIBITED_TARGET", "The requested target is protected by a guardrail.")
    If text [ "DEMO_TARGET_REFUSED" Quit ..WriteError(403, "DEMO_TARGET_REFUSED", "In the public demo only the synthetic demo targets can be changed.")
    If text [ "INVALID_REQUEST" Quit ..WriteError(400, "INVALID_REQUEST", "The request is invalid.")
    Quit ..WriteError(500, defaultCode, defaultMessage)
}

ClassMethod WritePermissionResponse(kind As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set authorization = ..GetForwardedAuthorization()
        If kind = "users" {
            Set errorCode = "USERS_UNAVAILABLE"
            Set errorMessage = "The user list is temporarily unavailable."
            Set tSC = ##class(MyOwn.Service.Permissions).GetUsers(authorization, .data, .source)
        } ElseIf kind = "roles" {
            Set errorCode = "ROLES_UNAVAILABLE"
            Set errorMessage = "The role list is temporarily unavailable."
            Set tSC = ##class(MyOwn.Service.Permissions).GetRoles(authorization, .data, .source)
        } Else {
            Set errorCode = "RESOURCES_UNAVAILABLE"
            Set errorMessage = "The resource list is temporarily unavailable."
            Set tSC = ##class(MyOwn.Service.Permissions).GetResources(authorization, .data, .source)
        }
        $$$ThrowOnError(tSC)
        Set payload = {}
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set payload.meta.source = source
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
        Set %response.Status = 500
        Set payload = {}
        Set payload.error = {}
        Set payload.error.code = errorCode
        Set payload.error.message = errorMessage
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

ClassMethod WriteSuccess(data As %DynamicAbstractObject) As %Status
{
    Set payload = {}
    Set payload.data = data
    Set payload.meta = {}
    Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
    Set %response.ContentType = "application/json; charset=utf-8"
    Write payload.%ToJSON()
    Quit $$$OK
}

/// IRIS consumes the standard Authorization header while authenticating the
/// request. The browser therefore mirrors it into this same-origin-only header
/// so the backend can authenticate its local SysAdmin API v2 calls.
ClassMethod GetForwardedAuthorization() As %String [ Private ]
{
    Set authorization = $Get(%request.CgiEnvs("HTTP_X_MYOWN_SYSADMIN_AUTHORIZATION"))
    If authorization = "" Set authorization = $Get(%request.CgiEnvs("HTTP_AUTHORIZATION"))
    Quit authorization
}

ClassMethod WriteError(status As %Integer, code As %String, message As %String) As %Status
{
    Set %response.Status = status
    Set payload = {}
    Set payload.error = {}
    Set payload.error.code = code
    Set payload.error.message = message
    Set %response.ContentType = "application/json; charset=utf-8"
    Write payload.%ToJSON()
    Quit $$$OK
}

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set %response.CharSet = "UTF-8"
    Set %response.Headers("X-Content-Type-Options") = "nosniff"
    Set %response.Headers("Cache-Control") = "no-store"
    If (pMethod '= "OPTIONS") && ('##class(MyOwn.Service.Access).CanView()) {
        Set pContinue = 0
        Do ..WriteError(403, "PORTAL_ACCESS_REQUIRED", "Your IRIS account is not authorized to use MyOwn Portal.")
        Quit tSC
    }
    If (pMethod '= "OPTIONS") && ##class(MyOwn.Demo.Mode).Enabled() {
        Set reason = ..DemoRefusal(pUrl, pMethod)
        If reason '= "" {
            Set pContinue = 0
            Do ##class(MyOwn.Service.Audit).RecordAgent("DemoRefused", 0, pMethod _ " " _ $Extract(pUrl, 1, 80), 0, reason, 0)
            Do ..WriteError(403, "DEMO_MODE_FORBIDDEN", $Select(reason = "real-system": "The public demo does not change the real system.", 1: "The demo account cannot use this function."))
        }
    }
    ; /openapi.json and /docs (MyOwn.REST.Docs), after the same access checks as every route.
    If pContinue Set tSC = ##super(pUrl, pMethod, .pContinue)
    Quit tSC
}

/// Demo mode rules, "" when allowed. Changes to the real system (users and roles, web
/// applications, tasks, the API explorer) are refused for everyone; the demo account may only
/// read, run scenarios, confirm or reject proposals and reset the demo, and sees no settings.
ClassMethod DemoRefusal(url As %String, method As %String) As %String
{
    If (method '= "GET") && $Match(url, "/(permissions/.*|applications/state|tasks/action|apis/test)") Quit "real-system"
    If '##class(MyOwn.Demo.Mode).IsDemoUser() Quit ""
    If method = "GET" Quit $Select($Match(url, "/agent/(config|pricing)"): "demo-account", 1: "")
    If $Match(url, "/(agent/simulate|agent/proposals/\d+/(confirm|reject)|demo/reset)") Quit ""
    Quit "demo-account"
}

ClassMethod CanOperateProposals() As %Boolean [ Private ]
{
    If ##class(MyOwn.Service.Access).CanManage() Quit 1
    Quit ##class(MyOwn.Demo.Mode).Enabled() && ##class(MyOwn.Demo.Mode).IsDemoUser()
}

/// One scenario for this client address and this session in the current minute.
ClassMethod DemoRateAllowed(Output retryAfter As %Integer) As %Boolean [ Private ]
{
    Set limit = ##class(MyOwn.Demo.Mode).SimulationsPerMinute()
    Set address = $Get(%request.CgiEnvs("REMOTE_ADDR"))
    Set session = $Select($IsObject($Get(%session)): %session.SessionId, 1: "")
    If '##class(MyOwn.Demo.RateLimit).Allow("ip:" _ address, limit, .retryAfter) Quit 0
    If session = "" Quit 1
    Quit ##class(MyOwn.Demo.RateLimit).Allow("session:" _ session, limit, .retryAfter)
}

/// Demo mode state: whether it is on, whether the caller is the demo account, the reset interval and, in demo mode, the synthetic targets.
ClassMethod DemoState() As %Status
{
    Set data = {"demoMode": (##class(MyOwn.Demo.Mode).Enabled()), "isDemoUser": (##class(MyOwn.Demo.Mode).IsDemoUser()), "resetHours": (##class(MyOwn.Demo.Mode).ResetHours()), "simulationsPerMinute": (##class(MyOwn.Demo.Mode).SimulationsPerMinute())}
    If data.demoMode Set data.targets = ##class(MyOwn.Demo.Seed).Summary()
    Quit ..WriteSuccess(data)
}

/// "Reset demo" button (demo account, or an administrator) in demo mode only.
ClassMethod DemoReset() As %Status
{
    If '##class(MyOwn.Demo.Mode).Enabled() Quit ..WriteError(409, "DEMO_MODE_OFF", "The portal is not running in demo mode.")
    If '..CanOperateProposals() Quit ..WriteError(403, "FORBIDDEN", "Only the demo account can reset the demo.")
    If '##class(MyOwn.Demo.RateLimit).Allow("reset:" _ $Get(%request.CgiEnvs("REMOTE_ADDR")), 2, .retryAfter) {
        Set %response.Headers("Retry-After") = retryAfter
        Quit ..WriteError(429, "RATE_LIMITED", "The demo was reset recently; try again in a minute.")
    }
    Set tSC = ##class(MyOwn.Demo.Seed).Reset("button by " _ $Username)
    If $$$ISERR(tSC) Quit ..WriteError(500, "DEMO_RESET_FAILED", "The demo could not be reset.")
    Quit ..WriteSuccess({"reset": 1, "targets": (##class(MyOwn.Demo.Seed).Summary())})
}

}
