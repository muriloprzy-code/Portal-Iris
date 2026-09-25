Class MyOwn.Installer
{

/// Roles added to portal users only inside the /myown/api application.
Parameter SystemReadRole = "MyOwnSystemRead";

Parameter SystemAdminRole = "MyOwnSystemAdmin";

Parameter DemoTaskName = "MyOwn Portal health snapshot";

/// SQL-callable wrapper around Setup(), so the one-click installer can trigger
/// installation over the Atelier REST API (already built into every IRIS instance)
/// instead of needing an interactively authenticated terminal session. Returns "OK"
/// on success, or the error text otherwise -- never throws, so it is always safe to
/// call from SQL.
ClassMethod SetupViaSQL() As %String [ SqlName = MyOwnSetup, SqlProc ]
{
    Set tSC = ..Setup()
    If $$$ISOK(tSC) Quit "OK"
    Quit $System.Status.GetErrorText(tSC)
}

/// SQL-callable wrapper that loads every .cls file under the given local directory
/// (read directly off disk by the IRIS server process itself - no HTTP file upload
/// involved) and then runs Setup(). The one-click installer uploads only this
/// compiled class over the Atelier REST API and then calls this method to load
/// everything else, because uploading many files in a row through that API's
/// doc-put endpoint has proven unreliable on some Windows/IRIS setups. Returns
/// "OK" on success, or a description of the error otherwise -- never throws, so
/// it is always safe to call from SQL.
ClassMethod LoadAndSetupViaSQL(dir As %String) As %String [ SqlName = MyOwnLoadAndSetup, SqlProc ]
{
    Set tSC = $System.OBJ.LoadDir(dir, "ck", .errorLog, 1)
    If $$$ISERR(tSC) Quit "LOAD ERROR: "_$System.Status.GetErrorText(tSC)
    Quit ..SetupViaSQL()
}

/// Creates or updates the web application that serves the React frontend and REST API.
ClassMethod Setup() As %Status
{
    Set tSC = $$$OK
    Try {
        Set targetNamespace = $Namespace
        Set application = "/myown/api"

        Set tSC = ..EnsureHealthPatterns()
        $$$ThrowOnError(tSC)

        // Security.Applications is only available from the %SYS namespace.
        New $Namespace
        Set $Namespace = "%SYS"

        Set tSC = ..EnsureAccessControl()
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureAuditEvent()
        $$$ThrowOnError(tSC)

        // Portal users only hold the MyOwn roles, which do not include access to the
        // %SYS namespace. These application roles are added only while a request is
        // handled by /myown/api, so viewers and administrators never hold the system
        // database roles in a terminal or in any other application.
        Set matchRoles = "MyOwnViewer:" _ ..#SystemReadRole _ ",MyOwnAdministrator:" _ ..#SystemAdminRole

        Set exists = ##class(Security.Applications).Exists(application, .applicationObject, .tSC)
        If exists {
            Set properties("DispatchClass") = "MyOwn.REST"
            Set properties("Enabled") = 1
            Set properties("AutheEnabled") = 32
            Set properties("NameSpace") = targetNamespace
            Set properties("Resource") = "MyOwn.View"
            Set properties("MatchRoles") = matchRoles
            Set tSC = ##class(Security.Applications).Modify(application, .properties)
            $$$ThrowOnError(tSC)
        } Else {
            // A not-found status is expected when the application is first installed.
            Set tSC = $$$OK
            Set properties("Name") = application
            Set properties("DispatchClass") = "MyOwn.REST"
            Set properties("NameSpace") = targetNamespace
            Set properties("Enabled") = 1
            Set properties("AutheEnabled") = 32
            Set properties("CookiePath") = application
            Set properties("Resource") = "MyOwn.View"
            Set properties("MatchRoles") = matchRoles
            Set tSC = ##class(Security.Applications).Create(application, .properties)
            $$$ThrowOnError(tSC)
        }

        // The demonstration task is optional: a failure must not abort the installation.
        Set taskStatus = ..EnsureDemoTask(targetNamespace)
        If $$$ISERR(taskStatus) Write !, "MyOwn Portal: the demonstration task was not created: ", $System.Status.GetErrorText(taskStatus), !
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod EnsureHealthPatterns() As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%Prepare("SELECT COUNT(*) AS PatternCount FROM MyOwn.HealthPattern")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute()
        If result.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, result.%Message))
        Do result.%Next()
        If result.%Get("PatternCount") = 0 {
            Set tSC = ..AddHealthPattern("healthy", "Healthy baseline", "Healthy", "No immediate action is required. Continue monitoring the instance.", "0.05,0.05,0.05,0,0.05,1")
            $$$ThrowOnError(tSC)
            Set tSC = ..AddHealthPattern("disk-pressure", "Disk pressure", "Attention", "Free or archive disk space and review database and journal growth.", "1,0.4,0.1,0.1,0.2,0")
            $$$ThrowOnError(tSC)
            Set tSC = ..AddHealthPattern("database-capacity", "Database capacity pressure", "Attention", "Review database growth and increase capacity before free space becomes critical.", "0.4,1,0.1,0.1,0.2,0")
            $$$ThrowOnError(tSC)
            Set tSC = ..AddHealthPattern("lock-contention", "Lock contention", "Attention", "Inspect blocked processes and long-running transactions that are consuming the lock table.", "0.2,0.2,1,0.2,0.4,0")
            $$$ThrowOnError(tSC)
            Set tSC = ..AddHealthPattern("active-alerts", "Active serious alerts", "Critical", "Review IRIS system alerts and messages, then address the most recent serious event first.", "0.2,0.2,0.2,1,0.3,0")
            $$$ThrowOnError(tSC)
            Set tSC = ..AddHealthPattern("process-pressure", "Process pressure", "Attention", "Inspect the process list for unexpected or long-running jobs and confirm workload capacity.", "0.2,0.2,0.3,0.1,1,0")
            $$$ThrowOnError(tSC)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod AddHealthPattern(code As %String, title As %String, severity As %String, recommendation As %String, vector As %String) As %Status [ Private ]
{
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("INSERT INTO MyOwn.HealthPattern (Code, Title, Severity, Recommendation, MetricVector) VALUES (?, ?, ?, ?, TO_VECTOR(?, DOUBLE))")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(code, title, severity, recommendation, vector)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    Quit $$$OK
}

ClassMethod EnsureAccessControl() As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set exists = ##class(Security.Resources).Exists("MyOwn.View", .resource, .checkStatus)
        If 'exists {
            Set tSC = ##class(Security.Resources).Create("MyOwn.View", "Allows read-only access to MyOwn Portal.", "")
            $$$ThrowOnError(tSC)
        }
        Set exists = ##class(Security.Resources).Exists("MyOwn.Manage", .resource, .checkStatus)
        If 'exists {
            Set tSC = ##class(Security.Resources).Create("MyOwn.Manage", "Allows administrative actions in MyOwn Portal.", "")
            $$$ThrowOnError(tSC)
        }

        Set tSC = ..EnsureRole("MyOwnViewer", "Read-only access to MyOwn Portal.", "MyOwn.View:U")
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureRole("MyOwnAdministrator", "Administrative access to MyOwn Portal.", "MyOwn.View:U,MyOwn.Manage:U,%Admin_Secure:U,%Admin_Task:U")
        $$$ThrowOnError(tSC)

        // Application roles: granted by MatchRoles on /myown/api (see Setup).
        Set tSC = ..EnsureRole(..#SystemReadRole, "Read access to the IRIS system database, granted only inside MyOwn Portal.", "%DB_IRISSYS:R")
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureRole(..#SystemAdminRole, "Read and write access to the IRIS system database, granted only inside MyOwn Portal.", "%DB_IRISSYS:RW")
        $$$ThrowOnError(tSC)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Creates the role, or updates its description and resources when it already exists.
ClassMethod EnsureRole(name As %String, description As %String, resources As %String) As %Status [ Private ]
{
    Set exists = ##class(Security.Roles).Exists(name, .role, .checkStatus)
    If exists {
        Kill roleProperties
        Set roleProperties("Description") = description
        Set roleProperties("Resources") = resources
        Quit ##class(Security.Roles).Modify(name, .roleProperties)
    }
    Quit ##class(Security.Roles).Create(name, description, resources, "")
}

/// Creates one Task Manager task in the portal namespace so that Run, Suspend and
/// Resume can be demonstrated on a fresh instance. The task only records a health
/// score snapshot; it does not change the system.
ClassMethod EnsureDemoTask(targetNamespace As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        If ##class(%SYS.Task).FindId(..#DemoTaskName) = "" {
            Set task = ##class(%SYS.Task).%New()
            Set task.Name = ..#DemoTaskName
            Set task.Description = "Stores a periodic MyOwn Portal health score. Created by the MyOwn Portal installer."
            Set task.NameSpace = targetNamespace
            Set task.TaskClass = "MyOwn.Task.HealthSnapshot"
            Set task.RunAsUser = "_SYSTEM"
            Set tSC = task.%Save()
            $$$ThrowOnError(tSC)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Sets the _SYSTEM password from the MYOWN_DEMO_PASSWORD build argument for this
/// local demo container (see compose.yaml / .env.example). Broken out into a compiled
/// method -- rather than inline multi-line "If ... { }" blocks in docker/iris.script --
/// because a script piped into "iris session IRIS < file" runs one line at a time and
/// does not reliably parse multi-line curly-brace blocks the way compiled code does; a
/// method call is a single line and cannot hit that problem.
ClassMethod SetDemoSystemPassword(password As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If password = "" Quit
        New $Namespace
        Set $Namespace = "%SYS"
        If ##class(Security.Users).Exists("_SYSTEM", .tUser, .tStatus) {
            Set tUser.PasswordExternal = password
            Set tUser.ChangePassword = 0
            Set tUser.PasswordNeverExpires = 1
            Set tUser.AccountNeverExpires = 1
            Set tUser.Enabled = 1
            Set tSC = tUser.%Save()
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Prepares this instance to be safely captured into a container image. In particular
/// it clears the hostname IRIS stamps into the database, so that when the image is
/// later run under its real container hostname, IRIS does not mistake that for a
/// failover from the transient build container (e.g. BuildKit's "buildkitsandbox") and
/// show a "System appears to have failed over from node ..." warning. SYS.Container is
/// a %SYS-only system class that is not present on every edition or version, so its
/// absence here is not treated as an error -- this best-effort call is simply skipped.
ClassMethod PrepareForContainerBundling() As %Status
{
    Set tSC = $$$OK
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        If ##class(%Dictionary.CompiledClass).%ExistsId("SYS.Container") {
            Set tSC = ##class(SYS.Container).QuiesceForBundling()
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod EnsureAuditEvent() As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set exists = ##class(Security.Events).Exists("MyOwn", "Administration", "Change", .event, .checkStatus)
        If exists {
            Kill eventProperties
            Set eventProperties("Description") = "Administrative changes performed through MyOwn Portal."
            Set eventProperties("Enabled") = 1
            Set tSC = ##class(Security.Events).Modify("MyOwn", "Administration", "Change", .eventProperties)
        } Else {
            Set tSC = ##class(Security.Events).Create("MyOwn", "Administration", "Change", "Administrative changes performed through MyOwn Portal.", 1)
        }
        $$$ThrowOnError(tSC)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

}
