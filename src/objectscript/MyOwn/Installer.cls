Class MyOwn.Installer
{

/// Roles added to portal users only inside the /myown/api application.
Parameter SystemReadRole = "MyOwnSystemRead";

Parameter SystemAdminRole = "MyOwnSystemAdmin";

Parameter DemoTaskName = "MyOwn Portal health snapshot";

/// Application role for portal accounts without %All (viewer and demo): namespace databases
/// and SQL read access, granted only while /myown/api handles a request (see EnsureAccessControl).
Parameter PortalDataRole = "MyOwnPortalData";

/// Earlier name of PortalDataRole, removed on upgrade.
Parameter FormerDemoDataRole = "MyOwnDemoData";

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
    ; The production classes extend Ens.*: the namespace must be interoperability-enabled
    ; before they are compiled, not only later in Setup.
    Set tSC = ..EnsureInteroperability($Namespace)
    If $$$ISERR(tSC) Quit "INTEROPERABILITY ERROR: "_$System.Status.GetErrorText(tSC)
    Set tSC = $System.OBJ.LoadDir(dir, "ck", .errorLog, 1)
    If $$$ISERR(tSC) Quit "LOAD ERROR: "_$System.Status.GetErrorText(tSC)
    ; The AI Hub engine module (aihub/src next to src/objectscript) needs the %AI package.
    Set aihub = ##class(%File).NormalizeDirectory(##class(%File).NormalizeDirectory(dir) _ "../../aihub/src")
    If ##class(%Dictionary.CompiledClass).%ExistsId("%AI.Agent") && ##class(%File).DirectoryExists(aihub) {
        Set tSC = $System.OBJ.LoadDir(aihub, "ck", .errorLog, 1)
        If $$$ISERR(tSC) Quit "AIHUB LOAD ERROR: "_$System.Status.GetErrorText(tSC)
    }
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

        Set tSC = ..EnsureAccessControl(targetNamespace)
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureAuditEvent()
        $$$ThrowOnError(tSC)

        // Grant %SYS database roles only while /myown/api handles a request. Viewer and demo
        // accounts also get the namespace databases and SQL read access there, and nowhere else.
        Set matchRoles = "MyOwnViewer:" _ ..#SystemReadRole _ ":" _ ..#PortalDataRole _ ",MyOwnAdministrator:" _ ..#SystemAdminRole _ ",MyOwnDemo:" _ ..#SystemReadRole _ ":" _ ..#PortalDataRole

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
        // Synthetic demo targets always exist; the demo account and reset task follow MYOWN_DEMO_MODE.
        Set demoStatus = ..EnsurePortalSqlPrivileges()
        If $$$ISOK(demoStatus) Set demoStatus = ##class(MyOwn.Demo.Seed).EnsureSeeded()
        If $$$ISOK(demoStatus) Set demoStatus = ##class(MyOwn.Demo.Setup).Apply(targetNamespace)
        If $$$ISERR(demoStatus) Write !, "MyOwn Portal: the demo settings were not applied: ", $System.Status.GetErrorText(demoStatus), !
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
/// On a reinstall over a running production it restarts it: jobs of recompiled host classes
/// keep running the previous code, and old and new pipeline code mixed in one production
/// can call each other in a loop (seen as AgentGateway waiting on itself).
ClassMethod EnsureAgentProduction() As %Status [ Private ]
{
    Set production = "MyOwn.Production.Main"
    Set active = ##class(Ens.Director).GetActiveProductionName()
    ; In an image build the production is only set to start at boot. On IRIS for Health the
    ; Foundation job still holds the Ens runtime lock there, so starting (or stopping) a production
    ; would wait 30 s and leave ErrCanNotAcquireRuntimeLock errors in the Event Log of every new
    ; installation. MYOWN_IMAGE_BUILD is set only by the Dockerfile's build step.
    If $System.Util.GetEnviron("MYOWN_IMAGE_BUILD") = "1" {
        If (active '= "") && (active '= production) && '..IsEmptyFoundationProduction(active) Quit $$$ERROR($$$GeneralError, "Another production is already active: " _ active)
        Write !, "MyOwn Portal: image build, the agent production starts automatically when IRIS starts.", !
        Quit ##class(Ens.Director).SetAutoStart(production)
    }
    If (active = production) || ..IsEmptyFoundationProduction(active) {
        Set tSC = ##class(Ens.Director).StopProduction(30, 0)
        If $$$ISERR(tSC) Set tSC = ##class(Ens.Director).StopProduction(10, 1)
        If $$$ISERR(tSC) Quit tSC
        Set active = ""
    }
    If active '= "" Quit $$$ERROR($$$GeneralError, "Another production is already active: " _ active)
    ; Auto-start first: if starting now fails, IRIS still starts the production on the next boot.
    Set tSC = ##class(Ens.Director).SetAutoStart(production)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(Ens.Director).StartProduction(production)
}

/// On IRIS for Health, enabling interoperability creates and starts an empty
/// &lt;NS&gt;PKG.FoundationProduction. Only that generated, item-less production may be replaced
/// by the portal production; any other active production still blocks the installation.
ClassMethod IsEmptyFoundationProduction(name As %String) As %Boolean [ Private ]
{
    If name '= ($Translate($Namespace, "%") _ "PKG.FoundationProduction") Quit 0
    Set definition = ##class(Ens.Config.Production).%OpenId(name)
    If '$IsObject(definition) Quit 0
    Quit (definition.Items.Count() = 0)
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

ClassMethod EnsureAccessControl(targetNamespace As %String) As %Status [ Private ]
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

        // Login roles without %All (MyOwnViewer, MyOwnDemo) only open the portal; database access
        // comes from the application role MyOwnPortalData inside /myown/api.
        Set exists = ##class(Security.Resources).Exists("MyOwn.Demo", .resource, .checkStatus)
        If 'exists {
            Set tSC = ##class(Security.Resources).Create("MyOwn.Demo", "Allows the public demo actions of MyOwn Portal (scenarios, confirmations on synthetic targets, reset).", "")
            $$$ThrowOnError(tSC)
        }
        Set tSC = ..EnsureRole("MyOwnDemo", "Public demo account of MyOwn Portal: view, run scenarios, confirm or reject proposals on synthetic targets.", "MyOwn.View:U,MyOwn.Demo:U")
        $$$ThrowOnError(tSC)
        // The health score and host metrics are Embedded Python methods; recent builds (such as
        // 2026.3 AI Hub) require %Service_EmbeddedPython for them, older ones have no such resource.
        Set portalResources = ..NamespaceDatabaseResources(targetNamespace)
        If ##class(Security.Resources).Exists("%Service_EmbeddedPython") Set portalResources = portalResources _ ",%Service_EmbeddedPython:U"
        Set tSC = ..EnsureRole(..#PortalDataRole, "Namespace database access for MyOwn Portal accounts without %All, granted only inside /myown/api.", portalResources)
        $$$ThrowOnError(tSC)
        If ##class(Security.Roles).Exists(..#FormerDemoDataRole) {
            Set tSC = ##class(Security.Roles).Delete(..#FormerDemoDataRole)
            $$$ThrowOnError(tSC)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Creates the role, or updates its description and resources when it already exists.
/// Dynamic SQL checks SQL privileges for accounts without %All: the portal application role may
/// read the portal tables (writes go through objects). Runs in the portal namespace.
ClassMethod EnsurePortalSqlPrivileges() As %Status [ Private ]
{
    Set tSC = $$$OK
    For schema = "MyOwn", "MyOwn_Agent", "MyOwn_Demo", "MyOwn_Production_Msg", "MyOwn_Production_Process", "Ens_Config" {
        Set result = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON SCHEMA " _ schema _ " TO " _ ..#PortalDataRole)
        If result.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "GRANT on " _ schema _ ": " _ result.%Message)  Quit
    }
    Quit tSC
}

/// "%DB_x:RW,%DB_y:R" for the global (read-write) and routine (read) databases of a namespace.
ClassMethod NamespaceDatabaseResources(namespace As %String) As %String [ Private ]
{
    Set resources = ""
    Set tSC = ##class(Config.Namespaces).Get(namespace, .properties)
    If $$$ISERR(tSC) Quit resources
    For pair = $ListBuild("Globals", "RW"), $ListBuild("Routines", "R") {
        Set database = $Get(properties($List(pair, 1)))
        If database = "" Continue
        If $$$ISERR(##class(Config.Databases).Get(database, .databaseProperties)) Continue
        Set handle = ##class(SYS.Database).%OpenId($Get(databaseProperties("Directory")))
        If '$IsObject(handle) || (handle.ResourceName = "") Continue
        If resources [ (handle.ResourceName _ ":") Continue
        Set resources = resources _ $Select(resources = "": "", 1: ",") _ handle.ResourceName _ ":" _ $List(pair, 2)
    }
    Quit resources
}

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

/// Same values as MyOwn.Service.Audit (AgentType, AgentEvents), kept as literals: the Installer
/// must compile on its own (Install-All compiles it first) and runs in %SYS, where MyOwn classes
/// are not visible. UT-14-AUDIT fails if the two lists differ.
Parameter AgentAuditType = "Agent";

Parameter AgentAuditEvents = "Decision,ProposalCreated,ProposalConfirmed,ProposalRejected,ProposalExpired,ExecutionResult,ConfigChange,KillSwitch,ToolDenied,DemoRefused,DemoReset";

/// Registers the audit events outside a full Setup (idempotent). Switches to %SYS itself.
ClassMethod RegisterAuditEvents() As %Status
{
    New $Namespace
    Set $Namespace = "%SYS"
    Quit ..EnsureAuditEvent()
}

/// MyOwn/Administration/Change for portal administration, plus the agent events of the
/// specification (MyOwn/Agent/*). Must run in %SYS.
ClassMethod EnsureAuditEvent() As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..EnsureEvent("Administration", "Change", "Administrative changes performed through MyOwn Portal.")
        $$$ThrowOnError(tSC)
        Set events = ..#AgentAuditEvents
        For index = 1:1:$Length(events, ",") {
            Set name = $Piece(events, ",", index)
            Set tSC = ..EnsureEvent(..#AgentAuditType, name, "MyOwn Portal agent event " _ name _ " (agent marker and decision id in the event data).")
            $$$ThrowOnError(tSC)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod EnsureEvent(type As %String, name As %String, description As %String) As %Status [ Private ]
{
    If ##class(Security.Events).Exists("MyOwn", type, name, .event, .checkStatus) {
        Kill eventProperties
        Set eventProperties("Description") = description
        Set eventProperties("Enabled") = 1
        Quit ##class(Security.Events).Modify("MyOwn", type, name, .eventProperties)
    }
    Quit ##class(Security.Events).Create("MyOwn", type, name, description, 1)
}

}
