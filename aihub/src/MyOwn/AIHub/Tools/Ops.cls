/// Read-only tools offered to the model. They are class queries: AI Hub runs them as stored
/// procedures and returns {columns, rows, row_count, truncated, elapsed_ms}, cut at QUERYMAXROWS.
/// They read IRIS in the current namespace, with no credentials and no side effects. Text that
/// IRIS stores but does not control (task error messages) is returned in the "untrusted" column.
/// The Execute/Fetch/Close methods are Internal, so they are not offered as tools.
Class MyOwn.AIHub.Tools.Ops Extends %AI.Tool
{

/// Upper bound AI Hub applies to every query of this class (truncated = true beyond it).
Parameter QUERYMAXROWS = 20;

/// Recent runs of a task of this namespace, newest first: when it ran, whether it failed, the error text (untrusted) and whether the task is suspended. No rows: the task does not exist in this namespace or never ran.
Query GetTaskRuns(taskId As %Integer(DESCRIPTION="Numeric id of the task"), count As %Integer(DESCRIPTION="Number of runs, 1 to 10") = 5) As %Query(ROWSPEC = "started:%String,failed:%Boolean,untrusted:%String,suspended:%Boolean") [ SqlProc ]
{
}

ClassMethod GetTaskRunsExecute(ByRef qHandle As %Binary, taskId As %Integer, count As %Integer = 5) As %Status [ Internal ]
{
    Kill qHandle
    Set count = $Select(+count < 1: 1, +count > 10: 10, 1: +count)
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT Name, NameSpace, Suspended FROM %SYS.Task WHERE ID = ?")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(+taskId)
    If (result.%SQLCODE < 0) || 'result.%Next() Quit $$$OK
    ; A task of another namespace gives no rows, the same answer as an unknown id.
    If $ZConvert(result.%Get("NameSpace"), "U") '= $ZConvert($Namespace, "U") Quit $$$OK
    Set name = result.%Get("Name")
    Set suspended = ''result.%Get("Suspended")
    Set history = ##class(%SQL.Statement).%New()
    Set tSC = history.%Prepare("SELECT TOP " _ count _ " LastStarted, Status, Error FROM %SYS_Task.History WHERE Name = ? ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set rows = history.%Execute(name)
    While rows.%Next() {
        Set started = rows.%Get("LastStarted")
        Set failed = ''##class(MyOwn.Production.Service.TaskWatcher).IsFailure(rows.%Get("Status"))
        Set untrusted = $Extract(##class(MyOwn.Agent.Sanitize).Text(rows.%Get("Error"), 160), 1, 160)
        Set qHandle($Increment(qHandle)) = $ListBuild($Select(+started: $ZDateTime(started, 3, 1), 1: ""), failed, untrusted, suspended)
    }
    Quit $$$OK
}

ClassMethod GetTaskRunsFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ Internal, PlaceAfter = GetTaskRunsExecute ]
{
    Quit ..NextRow(.qHandle, .Row, .AtEnd)
}

ClassMethod GetTaskRunsClose(ByRef qHandle As %Binary) As %Status [ Internal, PlaceAfter = GetTaskRunsExecute ]
{
    Kill qHandle
    Quit $$$OK
}

/// Latest values of one health metric, newest first. metric is diskUsedPercent, databaseSpacePercent, lockTablePercent or processes; any other name gives no rows.
Query GetMetricHistory(metric As %String(DESCRIPTION="diskUsedPercent, databaseSpacePercent, lockTablePercent or processes"), count As %Integer(DESCRIPTION="Number of points, 1 to 20") = 10) As %Query(ROWSPEC = "at:%String,value:%Numeric") [ SqlProc ]
{
}

ClassMethod GetMetricHistoryExecute(ByRef qHandle As %Binary, metric As %String, count As %Integer = 10) As %Status [ Internal ]
{
    Kill qHandle
    Set count = $Select(+count < 1: 1, +count > 20: 20, 1: +count)
    Set tSC = ##class(MyOwn.Agent.Context.Health).MetricHistory(metric, count, .data)
    If $$$ISERR(tSC) Quit $$$OK
    Set iterator = data.%GetIterator()
    While iterator.%GetNext(, .point) {
        Set qHandle($Increment(qHandle)) = $ListBuild(point.at, point.value)
    }
    Quit $$$OK
}

ClassMethod GetMetricHistoryFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ Internal, PlaceAfter = GetMetricHistoryExecute ]
{
    Quit ..NextRow(.qHandle, .Row, .AtEnd)
}

ClassMethod GetMetricHistoryClose(ByRef qHandle As %Binary) As %Status [ Internal, PlaceAfter = GetMetricHistoryExecute ]
{
    Kill qHandle
    Quit $$$OK
}

/// Rows collected by an Execute method, in order: qHandle(n) holds row n, qHandle("at") the cursor.
ClassMethod NextRow(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer) As %Status [ Internal ]
{
    Set index = $Order(qHandle($Get(qHandle("at"))))
    If (index = "") || (index = "at") {
        Set Row = "", AtEnd = 1
        Quit $$$OK
    }
    Set qHandle("at") = index, Row = qHandle(index)
    Quit $$$OK
}

}
