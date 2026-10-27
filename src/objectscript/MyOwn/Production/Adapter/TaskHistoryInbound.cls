/// Inbound adapter of the TaskWatcher service. Every CallInterval it reads the newest rows of the
/// task history (all namespaces), counts consecutive failures per task name, newest first (a run
/// fails when its Status is not 1), and hands the service one MyOwn.Production.Adapter.TaskState
/// for each task of TaskNamespace that failed FailureThreshold times in a row, or is suspended
/// although its newest run succeeded. Duplicates are absorbed downstream by the agent cooldown and
/// the Gate, as before. A failed query is logged and retried at the next interval.
Class MyOwn.Production.Adapter.TaskHistoryInbound Extends Ens.InboundAdapter
{

Parameter SERVICEINPUTCLASS = "MyOwn.Production.Adapter.TaskState";

Parameter SETTINGS = "TaskNamespace:Basic,HistoryRows:Basic,FailureThreshold:Basic";

/// Namespace whose tasks the portal may manage; tasks of other namespaces are never handed on.
Property TaskNamespace As %String [ InitialExpression = "MYOWN" ];

/// Window of each scan: how many of the newest task history rows (all namespaces) are read.
Property HistoryRows As %Integer(MAXVAL = 1000, MINVAL = 1) [ InitialExpression = 200 ];

/// Failures in a row (newest first) that make a task worth triaging.
Property FailureThreshold As %Integer(MAXVAL = 100, MINVAL = 1) [ InitialExpression = 3 ];

/// Table the scan reads. Not a setting: tests point it at a missing table to force a query failure.
Property HistoryTable As %String [ InitialExpression = "%SYS_Task.History", Internal ];

/// History rows read by the last scan.
Property LastRowsRead As %Integer [ InitialExpression = 0 ];

Method OnTask() As %Status
{
    Set tSC = ..Collect(.found)
    If $$$ISERR(tSC) {
        $$$LOGSTATUS(tSC)
        Set tSC = $$$OK
    } Else {
        For index = 1:1:found.Count() {
            Set tSC = ..BusinessHost.ProcessInput(found.GetAt(index))
            If $$$ISERR(tSC) Quit
        }
    }
    Set ..BusinessHost.%WaitForNextCallInterval = 1
    Quit tSC
}

/// One scan: the tasks worth triaging, in task name order (public so tests can run it without a production).
Method Collect(Output found As %ListOfObjects) As %Status
{
    Set found = ##class(%ListOfObjects).%New()
    Set ..LastRowsRead = 0
    Set tSC = $$$OK
    Try {
        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%Prepare("SELECT TOP " _ (+..HistoryRows) _ " Name, Status, Error FROM " _ ..HistoryTable _ " ORDER BY ID DESC")
        If $$$ISERR(tSC) Quit
        Set result = statement.%Execute()
        If result.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, result.%Message)
            Quit
        }
        Set rows = ""
        While result.%Next() {
            Set rows = rows _ $ListBuild($ListBuild(result.%Get("Name"), result.%Get("Status"), result.%Get("Error")))
        }
        Set ..LastRowsRead = $ListLength(rows)
        Do ..Streaks(rows, .streaks)
        Set name = ""
        For {
            Set name = $Order(streaks(name), 1, streak)
            If name = "" Quit
            Set taskStatement = ##class(%SQL.Statement).%New()
            Set tSC = taskStatement.%Prepare("SELECT ID, NameSpace, Suspended FROM %SYS.Task WHERE Name = ?")
            If $$$ISERR(tSC) Quit
            Set taskResult = taskStatement.%Execute(name)
            If taskResult.%SQLCODE < 0 Continue
            If 'taskResult.%Next() Continue
            Set manageable = ($ZConvert(taskResult.%Get("NameSpace"), "U") = $ZConvert(..TaskNamespace, "U"))
            If 'manageable Continue
            Set suspended = +taskResult.%Get("Suspended")
            Set failures = $ListGet(streak, 1), lastOk = $ListGet(streak, 3)
            Set repeated = (failures >= ..FailureThreshold)
            Set recovered = (suspended && lastOk)
            If 'repeated && 'recovered Continue
            Set state = ##class(MyOwn.Production.Adapter.TaskState).%New()
            Set state.TaskId = taskResult.%Get("ID")
            Set state.Name = name
            Set state.Namespace = taskResult.%Get("NameSpace")
            Set state.Manageable = manageable
            Set state.Suspended = suspended
            Set state.Failures = failures
            Set state.LastError = $ListGet(streak, 2)
            Set state.LastOk = lastOk
            Do found.Insert(state)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// rows: $List of $ListBuild(name, status, error), newest first. streaks(name) =
/// $ListBuild(consecutive failures from the newest run, error of the newest failure, newest run ok).
ClassMethod Streaks(rows As %List, Output streaks)
{
    Kill streaks
    Set pointer = 0
    While $ListNext(rows, pointer, row) {
        Set name = $ListGet(row, 1)
        If name = "" Continue
        Set failed = ..IsFailure($ListGet(row, 2))
        If '$Data(streaks(name)) {
            Set streaks(name) = $ListBuild(0, "", 'failed)
            Set open(name) = 1
        }
        If 'open(name) Continue
        If failed {
            Set $List(streaks(name), 1) = $ListGet(streaks(name), 1) + 1
            If $ListGet(streaks(name), 2) = "" Set $List(streaks(name), 2) = $ListGet(row, 3)
        } Else {
            Set open(name) = 0
        }
    }
}

/// A history row is a failure only when its Status is not 1. Error holds the message of every
/// row ("Success", "Task suspended", "Task has expired ...", in the instance language), so it
/// cannot tell a failure apart.
ClassMethod IsFailure(status As %String) As %Boolean
{
    Quit (status '= "") && ($Piece(status, " ", 1) '= "1")
}

}
