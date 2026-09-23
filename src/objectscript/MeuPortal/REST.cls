Class MeuPortal.REST Extends %CSP.REST
{

/// Authenticated REST entry point for the Meu Portal administration interface.

/// The React frontend is served from the same origin (or through the Vite proxy
/// during development), so cross-origin requests are deliberately not accepted.
Parameter HandleCorsRequest = 0;

Parameter UseSession = 1;

XData UrlMap
{
<Routes>
  <Route Url="/health" Method="GET" Call="Health" />
  <Route Url="/session" Method="GET" Call="CurrentSession" />
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
</Routes>
}

ClassMethod Health() As %Status
{
    Set tSC = $$$OK
    Set payload = {}
    Set payload.data = {}
    Set payload.data.status = "ok"
    Set payload.data.application = "Meu Portal"
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
    Set tSC = ##class(MeuPortal.Service.Access).Current(.access)
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
        Set tSC = ##class(MeuPortal.Service.System).GetSummary(.data)
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
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set tSC = ##class(MeuPortal.Service.System).GetProcesses(.data)
        $$$ThrowOnError(tSC)
        Set payload.data = data
        Set payload.meta = {}
        Set payload.meta.timestamp = $ZDateTime($Horolog, 3, 1)
        Set payload.meta.limit = 25
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

ClassMethod SystemHealthReport() As %Status
{
    Set tSC = ##class(MeuPortal.Service.HealthAnalysis).GetReport(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "HEALTH_REPORT_UNAVAILABLE", "The instance health report is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod PermissionUsers() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("users")
}

ClassMethod PermissionRoles() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("roles")
}

ClassMethod PermissionResources() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WritePermissionResponse("resources")
}

ClassMethod PermissionUserDetail(user As %String) As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MeuPortal.Service.Permissions).GetUserDetail(user, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "USER_NOT_FOUND", "The requested user could not be found.")
    Quit ..WriteSuccess(data)
}

ClassMethod PermissionUserEffective(user As %String) As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MeuPortal.Service.Permissions).GetUserDetail(user, .detail)
    If $$$ISERR(tSC) Quit ..WriteError(404, "USER_NOT_FOUND", "The requested user could not be found.")
    Set data = {}
    Set data.user = detail.name
    Set data.roles = detail.effectiveRoles
    Set data.permissions = detail.effectivePermissions
    Quit ..WriteSuccess(data)
}

ClassMethod PermissionRoleDetail(role As %String) As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MeuPortal.Service.Permissions).GetRoleDetail(role, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "ROLE_NOT_FOUND", "The requested role could not be found.")
    Quit ..WriteSuccess(data)
}

ClassMethod AddPermissionUserRole(user As %String) As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    If '##class(MeuPortal.Service.Permissions).CanManage() Quit ..WriteError(403, "FORBIDDEN", "You do not have permission to manage user roles.")
    Set parseError = 0
    Try {
        Set body = {}.%FromJSON(%request.Content)
        Set role = body.%Get("role")
    } Catch exception {
        Set parseError = 1
    }
    If parseError Quit ..WriteError(400, "INVALID_JSON", "A valid JSON body is required.")
    If role = "" Quit ..WriteError(400, "ROLE_REQUIRED", "The role field is required.")
    If role = "%All" Quit ..WriteError(400, "PROTECTED_ROLE", "The %All role cannot be changed through Meu Portal.")

    Set tSC = ##class(MeuPortal.Service.Permissions).AddUserRole(user, role, .data)
    Do ##class(MeuPortal.Service.Audit).Record("AssignRole", user _ "/" _ role, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "ROLE_ASSIGNMENT_FAILED", "The role could not be assigned to this user.")
    Quit ..WriteSuccess(data)
}

ClassMethod RemovePermissionUserRole(user As %String, role As %String) As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    If '##class(MeuPortal.Service.Permissions).CanManage() Quit ..WriteError(403, "FORBIDDEN", "You do not have permission to manage user roles.")
    If role = "%All" Quit ..WriteError(400, "PROTECTED_ROLE", "The %All role cannot be changed through Meu Portal.")

    Set tSC = ##class(MeuPortal.Service.Permissions).RemoveUserRole(user, role, .data)
    Do ##class(MeuPortal.Service.Audit).Record("RemoveRole", user _ "/" _ role, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "ROLE_REMOVAL_FAILED", "The role could not be removed from this user.")
    Quit ..WriteSuccess(data)
}

ClassMethod Applications() As %Status
{
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set tSC = ##class(MeuPortal.Service.Applications).GetApplications(.data)
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
        Set payload.error.code = "APPLICATIONS_UNAVAILABLE"
        Set payload.error.message = "The web application inventory is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

ClassMethod ApplicationDetail() As %Status
{
    Set application = $Get(%request.Data("name", 1))
    If application = "" Quit ..WriteError(400, "APPLICATION_REQUIRED", "The application name is required.")

    Set tSC = ##class(MeuPortal.Service.Applications).GetApplication(application, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "APPLICATION_NOT_FOUND", "The requested web application could not be found.")
    Quit ..WriteSuccess(data)
}

ClassMethod SetApplicationState() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    If '##class(MeuPortal.Service.Applications).CanManage() Quit ..WriteError(403, "FORBIDDEN", "You do not have permission to manage web applications.")
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

    Set tSC = ##class(MeuPortal.Service.Applications).GetApplication(application, .detail)
    If $$$ISERR(tSC) Quit ..WriteError(404, "APPLICATION_NOT_FOUND", "The requested web application could not be found.")
    If 'detail.manageable Quit ..WriteError(400, "PROTECTED_APPLICATION", detail.protectionReason)

    Set tSC = ##class(MeuPortal.Service.Applications).SetApplicationEnabled(application, enabled, .data)
    Do ##class(MeuPortal.Service.Audit).Record($Select(enabled:"EnableApplication", 1:"DisableApplication"), application, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "APPLICATION_UPDATE_FAILED", "The web application state could not be changed.")
    Quit ..WriteSuccess(data)
}

ClassMethod TestAPI() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
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

    Set authorization = $Get(%request.CgiEnvs("HTTP_AUTHORIZATION"))
    Set port = +$Get(%request.CgiEnvs("SERVER_PORT"))
    If port = 0 Set port = 52773
    Set tSC = ##class(MeuPortal.Service.APIExplorer).Execute(method, path, headers, body, authorization, port, .data)
    If (normalizedMethod '= "GET") && (normalizedMethod '= "HEAD") Do ##class(MeuPortal.Service.Audit).Record("APIRequest" _ normalizedMethod, path, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "API_REQUEST_REJECTED", "The request was rejected or could not be completed.")
    Quit ..WriteSuccess(data)
}

ClassMethod OpenAPI() As %Status
{
    Set spec = {}
    Set spec.openapi = "3.0.3"
    Set spec.info = {}
    Set spec.info.title = "Meu Portal API"
    Set spec.info.version = "1.0.0"
    Set spec.info.description = "Local administration API for InterSystems IRIS."
    Set spec.servers = []
    Set server = {}
    Set server.url = "/meuportal/api"
    Do spec.servers.%Push(server)
    Set spec.paths = {}
    Do ..AddOpenAPIPath(spec.paths, "/health", "get", "Check API and IRIS availability")
    Do ..AddOpenAPIPath(spec.paths, "/system/summary", "get", "Read the IRIS system summary")
    Do ..AddOpenAPIPath(spec.paths, "/system/health-report", "get", "Analyze instance health with Embedded Python and IRIS Vector Search")
    Do ..AddOpenAPIPath(spec.paths, "/system/processes", "get", "List active IRIS processes")
    Do ..AddOpenAPIPath(spec.paths, "/permissions/users", "get", "List IRIS users")
    Do ..AddOpenAPIPath(spec.paths, "/applications", "get", "List IRIS web applications")
    Do ..AddOpenAPIPath(spec.paths, "/security", "get", "Read sanitized security metadata")
    Do ..AddOpenAPIPath(spec.paths, "/tasks", "get", "List scheduled tasks")
    Do ..AddOpenAPIPath(spec.paths, "/logs", "get", "Read sanitized IRIS log events")
    Do ..AddOpenAPIPath(spec.paths, "/apis/test", "post", "Execute a bounded local API request")
    Set %response.ContentType = "application/vnd.oai.openapi+json;version=3.0"
    Write spec.%ToJSON()
    Quit $$$OK
}

ClassMethod AddOpenAPIPath(paths As %DynamicObject, path As %String, method As %String, summary As %String) As %Status [ Private ]
{
    Set pathItem = {}
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
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set tSC = ##class(MeuPortal.Service.Tasks).GetTasks(.data)
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
        Set payload.error.code = "TASKS_UNAVAILABLE"
        Set payload.error.message = "The task inventory is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

ClassMethod TaskDetail() As %Status
{
    Set id = +$Get(%request.Data("id", 1))
    If id < 1 Quit ..WriteError(400, "TASK_REQUIRED", "A valid task ID is required.")
    Set tSC = ##class(MeuPortal.Service.Tasks).GetTask(id, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "TASK_NOT_FOUND", "The requested task could not be found.")
    Quit ..WriteSuccess(data)
}

ClassMethod TaskAction() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
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

    Set tSC = ##class(MeuPortal.Service.Tasks).GetTask(id, .detail)
    If $$$ISERR(tSC) Quit ..WriteError(404, "TASK_NOT_FOUND", "The requested task could not be found.")
    If 'detail.manageable Quit ..WriteError(403, "PROTECTED_TASK", detail.protectionReason)

    Set tSC = ##class(MeuPortal.Service.Tasks).PerformAction(id, action, .data)
    Do ##class(MeuPortal.Service.Audit).Record("Task" _ $ZConvert(action, "T"), "Task " _ id, $$$ISOK(tSC))
    If $$$ISERR(tSC) Quit ..WriteError(400, "TASK_ACTION_FAILED", "The task action could not be completed.")
    Quit ..WriteSuccess(data)
}

ClassMethod Security() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set tSC = ##class(MeuPortal.Service.Security).GetInventory(.data)
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
        Set payload.error.code = "SECURITY_INVENTORY_UNAVAILABLE"
        Set payload.error.message = "The security inventory is temporarily unavailable."
        Set %response.ContentType = "application/json; charset=utf-8"
        Write payload.%ToJSON()
    }
    Quit $$$OK
}

ClassMethod SecuritySummary() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set tSC = ##class(MeuPortal.Service.Security).GetSummary(.data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "SECURITY_SUMMARY_UNAVAILABLE", "The security summary is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod SecurityCertificates() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("certificates")
}

ClassMethod SecurityOAuth() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("oauth")
}

ClassMethod SecurityCredentials() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Quit ..WriteSecurityCategory("credentials")
}

ClassMethod SecurityDetail() As %Status
{
    If '##class(MeuPortal.Service.Access).CanManage() Quit ..WriteError(403, "FORBIDDEN", "Administrator access is required.")
    Set category = $Get(%request.Data("category", 1))
    Set name = $Get(%request.Data("name", 1))
    Set type = $Get(%request.Data("type", 1))
    If (category = "") || (name = "") Quit ..WriteError(400, "SECURITY_ITEM_REQUIRED", "The security category and item name are required.")
    Set tSC = ##class(MeuPortal.Service.Security).GetDetail(category, name, type, .data)
    If $$$ISERR(tSC) Quit ..WriteError(404, "SECURITY_ITEM_NOT_FOUND", "The requested security item could not be found.")
    Quit ..WriteSuccess(data)
}

ClassMethod WriteSecurityCategory(category As %String) As %Status
{
    Set tSC = ##class(MeuPortal.Service.Security).GetCategory(category, .data)
    If $$$ISERR(tSC) Quit ..WriteError(500, "SECURITY_CATEGORY_UNAVAILABLE", "The requested security inventory is temporarily unavailable.")
    Quit ..WriteSuccess(data)
}

ClassMethod Logs() As %Status
{
    Set tSC = $$$OK
    Try {
        Set payload = {}
        Set tSC = ##class(MeuPortal.Service.Logs).GetLogs(.data)
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

ClassMethod WritePermissionResponse(kind As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If kind = "users" {
            Set errorCode = "USERS_UNAVAILABLE"
            Set errorMessage = "The user list is temporarily unavailable."
            Set tSC = ##class(MeuPortal.Service.Permissions).GetUsers(.data)
        } ElseIf kind = "roles" {
            Set errorCode = "ROLES_UNAVAILABLE"
            Set errorMessage = "The role list is temporarily unavailable."
            Set tSC = ##class(MeuPortal.Service.Permissions).GetRoles(.data)
        } Else {
            Set errorCode = "RESOURCES_UNAVAILABLE"
            Set errorMessage = "The resource list is temporarily unavailable."
            Set tSC = ##class(MeuPortal.Service.Permissions).GetResources(.data)
        }
        $$$ThrowOnError(tSC)
        Set payload = {}
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
    If (pMethod '= "OPTIONS") && ('##class(MeuPortal.Service.Access).CanView()) {
        Set pContinue = 0
        Do ..WriteError(403, "PORTAL_ACCESS_REQUIRED", "Your IRIS account is not authorized to use Meu Portal.")
    }
    Quit tSC
}

}
