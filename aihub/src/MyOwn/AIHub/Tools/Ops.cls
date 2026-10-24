/// Read-only tools offered to the model. They read IRIS through SQL in the current namespace,
/// with no credentials and no side effects, and return compact JSON. Text that IRIS stores
/// but does not control (task error messages) is returned under "untrusted".
Class MyOwn.AIHub.Tools.Ops Extends %AI.Tool
{

/// Recent runs of a task of this namespace, newest first: when it ran and whether it failed.
ClassMethod GetTaskRuns(taskId As %Integer(DESCRIPTION="Numeric id of the task"), count As %Integer(DESCRIPTION="Number of runs, 1 to 10") = 5) As %String
{
    Set count = $Select(+count < 1: 1, +count > 10: 10, 1: +count)
    Set out = {"taskId": (+taskId), "runs": []}
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT Name, NameSpace, Suspended FROM %SYS.Task WHERE ID = ?")
    If $$$ISERR(tSC) Quit {"error": "unavailable"}.%ToJSON()
    Set result = statement.%Execute(+taskId)
    If (result.%SQLCODE < 0) || 'result.%Next() Quit {"error": "unknown task"}.%ToJSON()
    If $ZConvert(result.%Get("NameSpace"), "U") '= $ZConvert($Namespace, "U") Quit {"error": "task of another namespace"}.%ToJSON()
    Set name = result.%Get("Name")
    Set out.suspended = +result.%Get("Suspended")
    Set history = ##class(%SQL.Statement).%New()
    Set tSC = history.%Prepare("SELECT TOP " _ count _ " LastStarted, Status, Error FROM %SYS_Task.History WHERE Name = ? ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit {"error": "unavailable"}.%ToJSON()
    Set rows = history.%Execute(name)
    While rows.%Next() {
        Set started = rows.%Get("LastStarted")
        Set run = {"started": ($Select(+started: $ZDateTime(started, 3, 1), 1: "")), "failed": (##class(MyOwn.Production.Service.TaskWatcher).IsFailure(rows.%Get("Status")))}
        Do run.%Set("failed", run.failed, "boolean")
        Set run.untrusted = $Extract(##class(MyOwn.Agent.Sanitize).Text(rows.%Get("Error"), 160), 1, 160)
        Do out.runs.%Push(run)
    }
    Quit out.%ToJSON()
}

/// Latest values of one health metric, newest first. metric is diskUsedPercent, databaseSpacePercent, lockTablePercent or processes.
ClassMethod GetMetricHistory(metric As %String(DESCRIPTION="diskUsedPercent, databaseSpacePercent, lockTablePercent or processes"), count As %Integer(DESCRIPTION="Number of points, 1 to 20") = 10) As %String
{
    Set count = $Select(+count < 1: 1, +count > 20: 20, 1: +count)
    Set tSC = ##class(MyOwn.Agent.Context.Health).MetricHistory(metric, count, .data)
    If $$$ISERR(tSC) Quit {"error": "unsupported metric"}.%ToJSON()
    Quit {"metric": (metric), "points": (data)}.%ToJSON()
}

}
