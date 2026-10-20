Class MyOwn.Installer
{

/// Roles added to portal users only inside the /myown/api application.
Parameter SystemReadRole = "MyOwnSystemRead";

Parameter SystemAdminRole = "MyOwnSystemAdmin";

Parameter DemoTaskName = "MyOwn Portal health snapshot";

Parameter AgentRetentionTaskName = "MyOwn Agent retention";

/// SQL wrapper used by the one-click installer. Returns "OK" or an error message.
ClassMethod SetupViaSQL() As %String [ SqlName = MyOwnSetup, SqlProc ]
{
    Set tSC = ..Setup()
    If $$$ISOK(tSC) Quit "OK"
    Quit $System.Status.GetErrorText(tSC)
}

/// Loads backend classes from a server-local directory and runs Setup().
/// Returns "OK" or an error message to the SQL caller.
ClassMethod LoadAndSetupViaSQL(dir As %String) As %String [ SqlName = MyOwnLoadAndSetup, SqlProc ]
{
    Set tSC = $System.OBJ.LoadDir(dir, "ck", .errorLog, 1)
    If $$$ISERR(tSC) Quit "LOAD ERROR: "_$System.Status.GetErrorText(tSC)
    Quit ..SetupViaSQL()
}

/// Returns a compact production status for installation and smoke-test scripts.
ClassMethod ProductionStatusViaSQL() As %String [ SqlName = MyOwnProductionStatus, SqlProc ]
{
    Set tSC = ##class(Ens.Director).GetProductionStatus(.production, .state, 10, 1)
    If $$$ISERR(tSC) Quit "ERROR: " _ $System.Status.GetErrorText(tSC)
    Quit production _ "|" _ state
}

/// Creates or updates the web application that serves the React frontend and REST API.
ClassMethod Setup() As %Status
{
    Set tSC = $$$OK
    Try {
        Set targetNamespace = $Namespace
        Set application = "/myown/api"

        Set tSC = ..EnsureInteroperability(targetNamespace)
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureHealthPatterns()
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureAgentDefaults()
        $$$ThrowOnError(tSC)

        // Security.Applications is only available from the %SYS namespace.
        New $Namespace
        Set $Namespace = "%SYS"

        Set tSC = ..EnsureAccessControl()
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureAuditEvent()
        $$$ThrowOnError(tSC)

        // Grant %SYS database roles only while /myown/api handles a request.
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
        Set taskStatus = ..EnsureAgentRetentionTask(targetNamespace)
        If $$$ISERR(taskStatus) Write !, "MyOwn Portal: the agent retention task was not created: ", $System.Status.GetErrorText(taskStatus), !

        Set $Namespace = targetNamespace
        Set productionStatus = ..EnsureAgentProduction()
        If $$$ISERR(productionStatus) Write !, "MyOwn Portal: the agent production was not started: ", $System.Status.GetErrorText(productionStatus), !
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Enables Interoperability for the application namespace when it is not already enabled.
ClassMethod EnsureInteroperability(targetNamespace As %String) As %Status [ Private ]
{
    If ##class(%EnsembleMgr).IsEnsembleNamespace(targetNamespace) Quit $$$OK
    Set tSC = ##class(%EnsembleMgr).EnableNamespace(targetNamespace, 0, .isPrimary, 0, 0)
    Quit tSC
}

/// Creates the safe, rules-first configuration used when AI Hub is not available.
ClassMethod EnsureAgentDefaults() As %Status [ Private ]
{
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    Quit tSC
}

/// Starts the agent production when no other production owns this namespace.
ClassMethod EnsureAgentProduction() As %Status [ Private ]
{
    Set production = "MyOwn.Production.Main"
    Set active = ##class(Ens.Director).GetActiveProductionName()
    If active = production Quit ##class(Ens.Director).SetAutoStart(production)
    If active '= "" Quit $$$ERROR($$$GeneralError, "Another production is already active: " _ active)
    Set tSC = ##class(Ens.Director).StartProduction(production)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(Ens.Director).SetAutoStart(production)
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
        Set exists = ##class(Security.Resources).Exists("MyOwn.Agent", .resource, .checkStatus)
        If 'exists {
            Set tSC = ##class(Security.Resources).Create("MyOwn.Agent", "Allows the MyOwn decision workflows to read operational context.", "")
            $$$ThrowOnError(tSC)
        }

        Set tSC = ..EnsureRole("MyOwnViewer", "Read-only access to MyOwn Portal.", "MyOwn.View:U")
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureRole("MyOwnAdministrator", "Administrative access to MyOwn Portal.", "MyOwn.View:U,MyOwn.Manage:U,%Admin_Operate:U,%Admin_Secure:U,%Admin_Task:U,%Admin_Wallet:U,%Admin_OAuth2_Client:U,%Admin_OAuth2_Server:U,%Admin_OAuth2_Registration:U")
        $$$ThrowOnError(tSC)

        // Application roles: granted by MatchRoles on /myown/api (see Setup).
        Set tSC = ..EnsureRole(..#SystemReadRole, "Read access to the IRIS system database, granted only inside MyOwn Portal.", "%DB_IRISSYS:R")
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureRole(..#SystemAdminRole, "Read and write access to the IRIS system database, granted only inside MyOwn Portal.", "%DB_IRISSYS:RW")
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureRole("MyOwnAgentRunner", "Runtime identity for MyOwn agent interoperability workflows.", "MyOwn.Agent:U,MyOwn.View:U")
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

/// Creates the demonstration health-snapshot task without changing system state.
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

/// Creates the daily task that removes transient agent telemetry after thirty days.
ClassMethod EnsureAgentRetentionTask(targetNamespace As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        If ##class(%SYS.Task).FindId(..#AgentRetentionTaskName) = "" {
            Set task = ##class(%SYS.Task).%New()
            Set task.Name = ..#AgentRetentionTaskName
            Set task.Description = "Removes old MyOwn agent events, tool calls, and ledger entries."
            Set task.NameSpace = targetNamespace
            Set task.TaskClass = "MyOwn.Task.AgentRetention"
            Set task.RunAsUser = "_SYSTEM"
            Set task.Type = 0
            Set task.TimePeriod = 0
            Set task.TimePeriodEvery = 1
            Set task.DailyStartTime = 7200
            Set task.RescheduleOnStart = 1
            Set tSC = task.%Save()
            $$$ThrowOnError(tSC)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Applies the local-demo _SYSTEM password supplied by the container build.
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

/// Clears transient container state before image capture when supported by IRIS.
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
