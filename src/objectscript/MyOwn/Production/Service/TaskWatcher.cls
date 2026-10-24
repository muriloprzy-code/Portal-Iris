Class MyOwn.Production.Service.TaskWatcher Extends Ens.BusinessService
{

Parameter ADAPTER = "Ens.InboundAdapter";

/// Failures in a row (newest first) that make a task worth triaging.
Parameter FAILURETHRESHOLD = 3;

/// Looks at tasks of the MYOWN namespace: repeated failures, or suspended tasks whose last run was ok.
/// Duplicates are absorbed by the agent cooldown (stable key = task id + state + failure band,
/// for example "3+"), and the Gate never creates a second proposal for the same task and action.
Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Scan()
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

Method Scan() As %Status [ Private ]
{
    // Newest history rows first; consecutive failures are counted per task name.
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 200 Name, Status, Error FROM %SYS_Task.History ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute()
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set name = result.%Get("Name")
        If name = "" Continue
        If '$Data(seen(name)) {
            Set seen(name) = 1
            Set failures(name) = 0
            Set lastError(name) = ""
            Set lastOk(name) = '..IsFailure(result.%Get("Status"))
            Set streak(name) = 1
        }
        If streak(name) {
            If ..IsFailure(result.%Get("Status")) {
                Set failures(name) = failures(name) + 1
                If lastError(name) = "" Set lastError(name) = result.%Get("Error")
            } Else {
                Set streak(name) = 0
            }
        }
    }
    Set name = ""
    For {
        Set name = $Order(seen(name))
        If name = "" Quit
        Set taskStatement = ##class(%SQL.Statement).%New()
        Set tSC = taskStatement.%Prepare("SELECT ID, NameSpace, Suspended FROM %SYS.Task WHERE Name = ?")
        If $$$ISERR(tSC) Quit
        Set taskResult = taskStatement.%Execute(name)
        If taskResult.%SQLCODE < 0 Continue
        If 'taskResult.%Next() Continue
        Set taskId = taskResult.%Get("ID")
        Set manageable = ($ZConvert(taskResult.%Get("NameSpace"), "U") = "MYOWN")
        Set suspended = +taskResult.%Get("Suspended")
        If 'manageable Continue
        Set repeated = (failures(name) >= ..#FAILURETHRESHOLD)
        Set recovered = (suspended && lastOk(name))
        If 'repeated && 'recovered Continue
        Set tSC = ..Emit(taskId, name, taskResult.%Get("NameSpace"), manageable, suspended, failures(name), lastError(name), lastOk(name))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// A history row is a failure only when its Status is not 1. Error holds the message of every
/// row ("Success", "Task suspended", "Task has expired ...", in the instance language), so it
/// cannot tell a failure apart.
ClassMethod IsFailure(status As %String) As %Boolean
{
    Quit (status '= "") && ($Piece(status, " ", 1) '= "1")
}

/// The task fields must match what the portal reads at confirmation time (id, name, namespace,
/// suspended, manageable); otherwise every proposal from the watcher fails with TARGET_CHANGED.
Method Emit(taskId As %Integer, name As %String, namespace As %String, manageable As %Boolean, suspended As %Boolean, failures As %Integer, lastError As %String, lastOk As %Boolean) As %Status [ Private ]
{
    Set context = {}
    Set context.source = "task-watcher"
    Set context.candidates = []
    Set context.untrustedData = {}
    Set context.task = {}
    Set context.task.id = taskId
    Set context.task.name = ##class(MyOwn.Agent.Sanitize).Text(name, 200)
    Set context.task.namespace = namespace
    Set context.task.manageable = +manageable
    Set context.task.suspended = +suspended
    Set context.task.consecutiveFailures = failures
    Set context.task.lastRunOk = +lastOk
    Set context.untrustedData.lastError = ##class(MyOwn.Agent.Sanitize).Text(lastError, 1000)
    Set candidate = ##class(MyOwn.Agent.Context.Tasks).Candidate(context.task)
    Do context.candidates.%Push(candidate)
    Set request = ##class(MyOwn.Production.Msg.IncidentEvent).%New()
    Set request.Source = "task"
    Set request.ContextJSON = context.%ToJSON()
    Set request.TraceId = $System.Util.CreateGUID()
    Set request.Fingerprint = $ZCRC(request.ContextJSON, 7) _ ":" _ $Length(request.ContextJSON)
    Quit ..SendRequestAsync("TriageProcess", request, 0)
}

}
