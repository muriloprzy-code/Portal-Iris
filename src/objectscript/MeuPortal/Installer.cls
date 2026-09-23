Class MeuPortal.Installer
{

/// Roles added to portal users only inside the /meuportal/api application.
Parameter SystemReadRole = "MeuPortalSystemRead";

Parameter SystemAdminRole = "MeuPortalSystemAdmin";

Parameter DemoTaskName = "Meu Portal health snapshot";

/// Creates or updates the web application that serves the React frontend and REST API.
ClassMethod Setup() As %Status
{
    Set tSC = $$$OK
    Try {
        Set targetNamespace = $Namespace
        Set application = "/meuportal/api"

        Set tSC = ..EnsureHealthPatterns()
        $$$ThrowOnError(tSC)

        // Security.Applications is only available from the %SYS namespace.
        New $Namespace
        Set $Namespace = "%SYS"

        Set tSC = ..EnsureAccessControl()
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureAuditEvent()
        $$$ThrowOnError(tSC)

        // Portal users only hold the MeuPortal roles, which do not include access to the
        // %SYS namespace. These application roles are added only while a request is
        // handled by /meuportal/api, so viewers and administrators never hold the system
        // database roles in a terminal or in any other application.
        Set matchRoles = "MeuPortalViewer:" _ ..#SystemReadRole _ ",MeuPortalAdministrator:" _ ..#SystemAdminRole

        Set exists = ##class(Security.Applications).Exists(application, .applicationObject, .tSC)
        If exists {
            Set properties("DispatchClass") = "MeuPortal.REST"
            Set properties("Enabled") = 1
            Set properties("AutheEnabled") = 32
            Set properties("NameSpace") = targetNamespace
            Set properties("Resource") = "MeuPortal.View"
            Set properties("MatchRoles") = matchRoles
            Set tSC = ##class(Security.Applications).Modify(application, .properties)
            $$$ThrowOnError(tSC)
        } Else {
            // A not-found status is expected when the application is first installed.
            Set tSC = $$$OK
            Set properties("Name") = application
            Set properties("DispatchClass") = "MeuPortal.REST"
            Set properties("NameSpace") = targetNamespace
            Set properties("Enabled") = 1
            Set properties("AutheEnabled") = 32
            Set properties("CookiePath") = application
            Set properties("Resource") = "MeuPortal.View"
            Set properties("MatchRoles") = matchRoles
            Set tSC = ##class(Security.Applications).Create(application, .properties)
            $$$ThrowOnError(tSC)
        }

        // The demonstration task is optional: a failure must not abort the installation.
        Set taskStatus = ..EnsureDemoTask(targetNamespace)
        If $$$ISERR(taskStatus) Write !, "Meu Portal: the demonstration task was not created: ", $System.Status.GetErrorText(taskStatus), !
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
        Set tSC = statement.%Prepare("SELECT COUNT(*) AS PatternCount FROM MeuPortal.HealthPattern")
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
    Set tSC = statement.%Prepare("INSERT INTO MeuPortal.HealthPattern (Code, Title, Severity, Recommendation, MetricVector) VALUES (?, ?, ?, ?, TO_VECTOR(?, DOUBLE))")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(code, title, severity, recommendation, vector)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    Quit $$$OK
}

ClassMethod EnsureAccessControl() As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set exists = ##class(Security.Resources).Exists("MeuPortal.View", .resource, .checkStatus)
        If 'exists {
            Set tSC = ##class(Security.Resources).Create("MeuPortal.View", "Allows read-only access to Meu Portal.", "")
            $$$ThrowOnError(tSC)
        }
        Set exists = ##class(Security.Resources).Exists("MeuPortal.Manage", .resource, .checkStatus)
        If 'exists {
            Set tSC = ##class(Security.Resources).Create("MeuPortal.Manage", "Allows administrative actions in Meu Portal.", "")
            $$$ThrowOnError(tSC)
        }

        Set tSC = ..EnsureRole("MeuPortalViewer", "Read-only access to Meu Portal.", "MeuPortal.View:U")
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureRole("MeuPortalAdministrator", "Administrative access to Meu Portal.", "MeuPortal.View:U,MeuPortal.Manage:U,%Admin_Secure:U,%Admin_Task:U")
        $$$ThrowOnError(tSC)

        // Application roles: granted by MatchRoles on /meuportal/api (see Setup).
        Set tSC = ..EnsureRole(..#SystemReadRole, "Read access to the IRIS system database, granted only inside Meu Portal.", "%DB_IRISSYS:R")
        $$$ThrowOnError(tSC)
        Set tSC = ..EnsureRole(..#SystemAdminRole, "Read and write access to the IRIS system database, granted only inside Meu Portal.", "%DB_IRISSYS:RW")
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
            Set task.Description = "Stores a periodic Meu Portal health score. Created by the Meu Portal installer."
            Set task.NameSpace = targetNamespace
            Set task.TaskClass = "MeuPortal.Task.HealthSnapshot"
            Set task.RunAsUser = "_SYSTEM"
            Set tSC = task.%Save()
            $$$ThrowOnError(tSC)
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
        Set exists = ##class(Security.Events).Exists("MeuPortal", "Administration", "Change", .event, .checkStatus)
        If exists {
            Kill eventProperties
            Set eventProperties("Description") = "Administrative changes performed through Meu Portal."
            Set eventProperties("Enabled") = 1
            Set tSC = ##class(Security.Events).Modify("MeuPortal", "Administration", "Change", .eventProperties)
        } Else {
            Set tSC = ##class(Security.Events).Create("MeuPortal", "Administration", "Change", "Administrative changes performed through Meu Portal.", 1)
        }
        $$$ThrowOnError(tSC)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

}
