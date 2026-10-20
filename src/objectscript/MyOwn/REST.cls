Class MyOwn.REST Extends %CSP.REST
{

/// Authenticated REST entry point for the MyOwn Portal administration interface.

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
</Routes>
}

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
    Set payload.meta = {}
    Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)

    Set %response.ContentType = "application/json; charset=utf-8"
    Write payload.%ToJSON()
    Quit tSC
}

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

/// Confirms that this IRIS instance provides the required SysAdmin API v2.
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

ClassMethod SystemHealthReport() As %Status
{
    Set tSC = ##class(MyOwn.Service.HealthAnalysis).GetReport(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "HEALTH_REPORT_UNAVAILABLE", "The instance health report is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod PermissionUsers() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("users")
}

ClassMethod PermissionRoles() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("roles")
}

ClassMethod PermissionResources() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("resources")
}

ClassMethod PermissionUserDetail(user As %String) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Permissions).GetUserDetail(user, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "USER_NOT_FOUND", "The requested user could not be found.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

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

ClassMethod PermissionRoleDetail(role As %String) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Permissions).GetRoleDetail(role, authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(404, "ROLE_NOT_FOUND", "The requested role could not be found.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

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

ClassMethod OpenAPI() As %Status
{
    Set spec = {}
    Set spec.openapi = "3.0.3"
    Set spec.info = {}
    Set spec.info.title = "MyOwn Portal API"
    Set spec.info.version = "1.0.0"
    Set spec.info.description = "Local administration API for InterSystems IRIS."
    Set spec.servers = []
    Set server = {}
    Set server.url = "/myown/api"
    Do spec.servers.%Push(server)
    Set spec.paths = {}
    Do ..AddOpenAPIPath(spec.paths, "/health", "get", "Check API and IRIS availability")
    Do ..AddOpenAPIPath(spec.paths, "/sysadmin/status", "get", "Check the local IRIS SysAdmin API capability")
    Do ..AddOpenAPIPath(spec.paths, "/system/summary", "get", "Read the IRIS system summary")
    Do ..AddOpenAPIPath(spec.paths, "/system/health-report", "get", "Analyze instance health with Embedded Python and IRIS Vector Search")
    Do ..AddOpenAPIPath(spec.paths, "/system/processes", "get", "List active IRIS processes")
    Do ..AddOpenAPIPath(spec.paths, "/permissions/users", "get", "List IRIS users")
    Do ..AddOpenAPIPath(spec.paths, "/applications", "get", "List IRIS web applications")
    Do ..AddOpenAPIPath(spec.paths, "/security", "get", "Read sanitized security metadata")
    Do ..AddOpenAPIPath(spec.paths, "/tasks", "get", "List scheduled tasks")
    Do ..AddOpenAPIPath(spec.paths, "/logs", "get", "Read sanitized IRIS log events")
    Do ..AddOpenAPIPath(spec.paths, "/apis/test", "post", "Execute a bounded local API request")
    Do ..AddOpenAPIPath(spec.paths, "/agent/status", "get", "Read the agent subsystem status")
    Do ..AddOpenAPIPath(spec.paths, "/agent/config", "get", "Read the sanitized agent configuration")
    Do ..AddOpenAPIPath(spec.paths, "/agent/config", "put", "Update the agent configuration")
    Do ..AddOpenAPIPath(spec.paths, "/agent/killswitch", "post", "Enable or disable all agent actions")
    Do ..AddOpenAPIPath(spec.paths, "/agent/decisions", "get", "List recent agent decisions")
    Do ..AddOpenAPIPath(spec.paths, "/agent/decisions/{id}", "get", "Read an agent decision")
    Do ..AddOpenAPIPath(spec.paths, "/agent/proposals", "get", "List state-changing proposals")
    Do ..AddOpenAPIPath(spec.paths, "/agent/proposals/{id}/confirm", "post", "Confirm a pending proposal")
    Do ..AddOpenAPIPath(spec.paths, "/agent/proposals/{id}/reject", "post", "Reject a pending proposal")
    Do ..AddOpenAPIPath(spec.paths, "/agent/access-requests", "get", "List access requests visible to the current user")
    Do ..AddOpenAPIPath(spec.paths, "/agent/access-requests", "post", "Submit an access request")
    Do ..AddOpenAPIPath(spec.paths, "/agent/ledger/summary", "get", "Read agent observability totals")
    Do ..AddOpenAPIPath(spec.paths, "/agent/ledger", "get", "List agent execution ledger entries")
    Do ..AddOpenAPIPath(spec.paths, "/agent/traces/{traceId}", "get", "Read an end-to-end agent trace")
    Do ..AddOpenAPIPath(spec.paths, "/agent/pricing", "get", "List configured model prices")
    Do ..AddOpenAPIPath(spec.paths, "/agent/pricing", "put", "Create or update a model price")
    Do ..AddOpenAPIPath(spec.paths, "/agent/production/status", "get", "Read the interoperability production status")
    Do ..AddOpenAPIPath(spec.paths, "/agent/production/start", "post", "Start the agent production")
    Do ..AddOpenAPIPath(spec.paths, "/agent/production/stop", "post", "Stop the agent production")
    Do ..AddOpenAPIPath(spec.paths, "/agent/guardrails", "get", "Read the enforced agent guardrails")
    Do ..AddOpenAPIPath(spec.paths, "/agent/simulate", "post", "Run a deterministic demonstration scenario")
    Do ..AddOpenAPIPath(spec.paths, "/agent/analyze", "post", "Analyze the current instance health")
    Set %response.ContentType = "application/vnd.oai.openapi+json;version=3.0"
    Write spec.%ToJSON()
    Quit $$$OK
}

ClassMethod AddOpenAPIPath(paths As %DynamicObject, path As %String, method As %String, summary As %String) As %Status [ Private ]
{
    If paths.%IsDefined(path) {
        Set pathItem = paths.%Get(path)
    } Else {
        Set pathItem = {}
    }
    Set operation = {}
    Set operation.summary = summary
    Set operation.responses = {}
    Set response = {}
    Set response.description = "Successful response"
    Do operation.responses.%Set("200", response)
    Do pathItem.%Set(method, operation)
    Do paths.%Set(path, pathItem)
    Quit $$$OK
}

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

ClassMethod SecuritySummary() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set authorization = ..GetForwardedAuthorization()
    Set tSC = ##class(MyOwn.Service.Security).GetSummary(authorization, .data, .source)
    If $$$ISERR(tSC) Quit ..WriteError(500, "SECURITY_SUMMARY_UNAVAILABLE", "The security summary is temporarily unavailable.")
    Set data.integrationSource = source
    Quit ..WriteSuccess(data)
}

ClassMethod SecurityCertificates() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("certificates")
}

ClassMethod SecurityOAuth() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("oauth")
}

ClassMethod SecurityCredentials() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("credentials")
}

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

ClassMethod AgentStatus() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Status(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_STATUS_UNAVAILABLE", "The agent status is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentConfig() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Config).PublicView(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_CONFIG_UNAVAILABLE", "The agent configuration is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

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

ClassMethod AgentDecisions() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListDecisions(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_DECISIONS_UNAVAILABLE", "Agent decisions are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentDecisionDetail(id As %Integer) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).DecisionDetail(id, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "DECISION_NOT_FOUND", "The requested decision was not found.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentProposals() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set state = $Get(%request.Data("state", 1))
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListProposals(state, .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_PROPOSALS_UNAVAILABLE", "Agent proposals are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod ConfirmAgentProposal(id As %Integer) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(id, $Username, ..GetForwardedAuthorization(), .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "PROPOSAL_CONFIRM_FAILED", "The proposal could not be confirmed.")
    Quit ..WriteSuccess(data)
}

ClassMethod RejectAgentProposal(id As %Integer) As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
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

ClassMethod SubmitAgentAccessRequest() As %Status
{
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        Set role = body.%Get("role")
        Set justification = body.%Get("justification")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_REQUEST", "A valid JSON body is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).SubmitAccessRequest(role, justification, ..GetForwardedAuthorization(), $Username, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "ACCESS_REQUEST_FAILED", "The access request could not be submitted.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentAccessRequests() As %Status
{
    Set includeAll = ##class(MyOwn.Service.Access).CanManage()
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListAccessRequests($Username, includeAll, .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "ACCESS_REQUESTS_UNAVAILABLE", "Access requests are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentLedgerSummary() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).LedgerSummary(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_LEDGER_UNAVAILABLE", "Agent observability data is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentLedger() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListLedger(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_LEDGER_UNAVAILABLE", "Agent observability data is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentTrace(traceId As %String) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Trace(traceId, .data)
    If $$$ISERR(tSC) Quit ..WriteAgentError(tSC, "AGENT_TRACE_UNAVAILABLE", "The requested trace could not be loaded.")
    Quit ..WriteSuccess(data)
}

ClassMethod AgentPricing() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListPricing(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_PRICING_UNAVAILABLE", "Agent pricing is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

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

ClassMethod AgentProductionStatus() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ProductionStatus(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "PRODUCTION_STATUS_UNAVAILABLE", "The agent production status is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod StartAgentProduction() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ControlProduction("start", .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "PRODUCTION_START_FAILED", "The agent production could not be started.")
    Set auditStatus = ##class(MyOwn.Service.Audit).Record("AgentProductionStart", "MyOwn.Production.Main", 1)
    Quit ..WriteSuccess(data)
}

ClassMethod StopAgentProduction() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ControlProduction("stop", .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "PRODUCTION_STOP_FAILED", "The agent production could not be stopped.")
    Set auditStatus = ##class(MyOwn.Service.Audit).Record("AgentProductionStop", "MyOwn.Production.Main", 1)
    Quit ..WriteSuccess(data)
}

ClassMethod AgentGuardrails() As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Guardrails(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "GUARDRAILS_UNAVAILABLE", "Agent guardrails are temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod SimulateAgentScenario() As %Status
{
    If '##class(MyOwn.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit ..WriteError(500, "AGENT_CONFIG_UNAVAILABLE", "The agent configuration is temporarily unavailable.")
    If 'config.DemoMode Quit ..WriteError(403, "AGENT_DISABLED", "Demonstration scenarios are disabled.")
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
    }
    Quit tSC
}

}
