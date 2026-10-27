Class MyOwn.Production.Service.TaskWatcher Extends Ens.BusinessService
{

Parameter ADAPTER = "MyOwn.Production.Adapter.TaskHistoryInbound";

/// Receives from the adapter each task of the namespace worth triaging: repeated failures, or a
/// suspended task whose last run was ok (the scan and its settings live in the adapter).
/// Duplicates are absorbed by the agent cooldown (stable key = task id + state + failure band,
/// for example "3+"), and the Gate never creates a second proposal for the same task and action.
Method OnProcessInput(pInput As MyOwn.Production.Adapter.TaskState, Output pOutput As %RegisteredObject) As %Status
{
    If '$IsObject(pInput) Quit $$$OK
    Quit ..Emit(pInput.TaskId, pInput.Name, pInput.Namespace, pInput.Manageable, pInput.Suspended, pInput.Failures, pInput.LastError, pInput.LastOk)
}

/// Kept for callers outside the production (the AI Hub read-only tools); see the adapter.
ClassMethod IsFailure(status As %String) As %Boolean
{
    Quit ##class(MyOwn.Production.Adapter.TaskHistoryInbound).IsFailure(status)
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
