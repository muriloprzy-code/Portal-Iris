/// Tests of the production inbound adapters (scripts/Test-Adapters.ps1).
/// AdapterSmoke runs the adapters without a production; the TestFailingTask* procedures drive the
/// end-to-end check: a real task of this namespace fails, the running TaskWatcher picks it up and
/// the triage ends in a pending suspend proposal. Only tasks named with ..#TaskPrefix are touched.
Class MyOwn.Test.Adapter
{

Parameter TaskPrefix = "MyOwn Test failing task ";

ClassMethod Smoke() As %String [ SqlName = AdapterSmoke, SqlProc ]
{
    Set report = {"suite": "adapter-smoke", "results": [], "pass": 0, "fail": 0}
    Set logStart = ..LastLogId()
    Try {
        Do ..Checks(report)
    } Catch exception {
        Do ..Add(report, "AD-EXCEPTION", 0, exception.DisplayString())
    }
    ; The query-failure checks log on purpose; those entries are removed so the Event Log shows no false errors.
    Set removed = ..RemoveTestLogEntries(logStart)
    Do ..Add(report, "AD-08-EVENT-LOG", ..TestLogEntries(logStart) = 0, "The " _ removed _ " Event Log entries written on purpose by the failure checks were removed.")
    Kill ^||MyOwnAdapterTest
    Set report.summary = {"pass": (report.pass), "fail": (report.fail)}
    Quit report.%ToJSON()
}

ClassMethod Checks(report As %DynamicObject) [ Private ]
{
    Set tasks = "MyOwn.Production.Adapter.TaskHistoryInbound"
    Set logs = "MyOwn.Production.Adapter.LogEntriesInbound"

    ; Failure counting, on synthetic history rows (newest first; Status other than 1 is a failure).
    Set rows = $ListBuild($ListBuild("A", "0 ERROR", "e1"), $ListBuild("B", "1", "Success"), $ListBuild("A", "-1", "e2"), $ListBuild("A", "0 x", ""), $ListBuild("A", "1", "Success"), $ListBuild("A", "0 old", "e3"), $ListBuild("C", "", ""), $ListBuild("", "0", "no name"))
    Do $ClassMethod(tasks, "Streaks", rows, .streaks)
    Set a = streaks("A"), b = streaks("B"), c = streaks("C")
    Set names = "", name = ""
    For {
        Set name = $Order(streaks(name))
        If name = "" Quit
        Set names = names _ name
    }
    Do ..Add(report, "AD-01-STREAKS", ($ListGet(a, 1) = 3) && ($ListGet(a, 2) = "e1") && '$ListGet(a, 3) && ($ListGet(b, 1) = 0) && $ListGet(b, 3) && ($ListGet(c, 1) = 0) && (names = "ABC"), "Consecutive failures stop at the first success (A: 3, error of the newest failure); a success first gives 0; an empty Status is not a failure; rows without a name are ignored.")

    ; Empty: a namespace with no tasks hands nothing on.
    Set adapter = $ClassMethod(tasks, "%New")
    Set adapter.TaskNamespace = "MYOWN_TEST_NO_SUCH_NAMESPACE"
    Set tSC = adapter.Collect(.found)
    Do ..Add(report, "AD-02-EMPTY", $$$ISOK(tSC) && (found.Count() = 0), "No task of the configured namespace: no state is handed on, without error (" _ adapter.LastRowsRead _ " history rows read).")

    ; The window is respected.
    Set adapter = $ClassMethod(tasks, "%New")
    Set adapter.HistoryRows = 2
    Set tSC = adapter.Collect(.found)
    Set two = adapter.LastRowsRead
    Set adapter.HistoryRows = 1
    Set tSC1 = adapter.Collect(.found)
    Set total = ..HistoryRowCount()
    Do ..Add(report, "AD-03-LIMIT", $$$ISOK(tSC) && $$$ISOK(tSC1) && (two = $Select(total < 2: total, 1: 2)) && (adapter.LastRowsRead = $Select(total < 1: 0, 1: 1)), "HistoryRows bounds each scan: 2 rows read with HistoryRows=2 and 1 with HistoryRows=1 (" _ total _ " rows in the history).")

    ; A failed query: Collect reports it, OnTask logs it, hands nothing on and keeps the service polling.
    Set host = ##class(MyOwn.Test.AdapterHost).%New()
    Set adapter = $ClassMethod(tasks, "%New")
    Set adapter.HistoryTable = "MyOwn_Test.TESTIgnoreNoSuchHistoryTable"
    Set adapter.BusinessHost = host
    Set collected = adapter.Collect(.found)
    Set onTask = adapter.OnTask()
    Do ..Add(report, "AD-04-QUERY-FAILURE", $$$ISERR(collected) && $$$ISOK(onTask) && (host.Received.Count() = 0) && (host.%WaitForNextCallInterval = 1), "A query that fails is an error for Collect, but OnTask logs it and returns OK, hands nothing on and waits for the next interval.")

    ; OnTask hands every state to the service, one ProcessInput call each.
    Set host = ##class(MyOwn.Test.AdapterHost).%New()
    Set adapter = $ClassMethod(tasks, "%New")
    Set adapter.BusinessHost = host
    Set adapter.FailureThreshold = 1
    Set tSC = adapter.Collect(.expected)
    Set onTask = adapter.OnTask()
    Set same = (host.Received.Count() = expected.Count())
    For index = 1:1:host.Received.Count() {
        Set received = host.Received.GetAt(index)
        If '$IsObject(received) || 'received.%IsA("MyOwn.Production.Adapter.TaskState") || (received.Namespace '= "MYOWN") Set same = 0
    }
    Do ..Add(report, "AD-05-HANDOFF", $$$ISOK(tSC) && $$$ISOK(onTask) && same, "OnTask calls ProcessInput once per task state (" _ expected.Count() _ " now with FailureThreshold=1), each a TaskState of the configured namespace. A non-empty hand-off with real failures is checked end to end (AD-E2E).")

    ; Log adapter: empty, failed read, window.
    Set host = ##class(MyOwn.Test.AdapterHost).%New()
    Set adapter = $ClassMethod(logs, "%New")
    Set adapter.BusinessHost = host
    Set adapter.SourceClass = "MyOwn.Test.AdapterHost"
    Set ^||MyOwnAdapterTest("logs") = "empty"
    Set emptyOk = $$$ISOK(adapter.OnTask()) && (host.Received.Count() = 0)
    Set ^||MyOwnAdapterTest("logs") = "error"
    Set failed = adapter.Collect(.batch)
    Set errorOk = $$$ISERR(failed) && $$$ISOK(adapter.OnTask()) && (host.Received.Count() = 0)
    Set ^||MyOwnAdapterTest("logs") = "many"
    Set adapter.MaxEntries = 3
    Set tSC = adapter.OnTask()
    Set batchOk = $$$ISOK(tSC) && (host.Received.Count() = 1) && ([].%FromJSON(host.Received.GetAt(1).ItemsJSON).%Size() = 3)
    Do ..Add(report, "AD-06-LOGS", emptyOk && errorOk && batchOk, "Log adapter: no entries, nothing handed on; a failed read is logged and the service keeps polling; one batch of at most MaxEntries (3) entries otherwise.")

    ; The production carries the adapters with their settings.
    Set item = ..ProductionItem("TaskWatcher")
    Set logItem = ..ProductionItem("LogWatcher")
    Do ..Add(report, "AD-07-PRODUCTION", ($Parameter("MyOwn.Production.Service.TaskWatcher", "ADAPTER") = tasks) && ($Parameter("MyOwn.Production.Service.LogWatcher", "ADAPTER") = logs) && (item [ "TaskNamespace=MYOWN") && (item [ "HistoryRows=200") && (item [ "FailureThreshold=3") && (item [ "CallInterval=120") && (logItem [ "MaxEntries=10") && (logItem [ "CallInterval=120"), "TaskWatcher and LogWatcher use the portal adapters; the production sets " _ item _ " and " _ logItem _ ".")
}

/// Newest Event Log id of the namespace (0 when empty).
ClassMethod LastLogId() As %Integer [ Private ]
{
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) AS id FROM Ens_Util.Log")
    Quit $Select(result.%Next(): +result.%Get("id"), 1: 0)
}

/// Entries after afterId that the adapters wrote outside the production (no config name):
/// only the failure checks of this suite do that.
ClassMethod TestLogEntries(afterId As %Integer, Output ids As %List) As %Integer [ Private ]
{
    Set ids = ""
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Ens_Util.Log WHERE ID > ? AND (ConfigName IS NULL OR ConfigName = '') AND SourceClass IN ('MyOwn.Production.Adapter.TaskHistoryInbound', 'MyOwn.Production.Adapter.LogEntriesInbound')", afterId)
    While result.%Next() { Set ids = ids _ $ListBuild(result.%Get("ID")) }
    Quit $ListLength(ids)
}

ClassMethod RemoveTestLogEntries(afterId As %Integer) As %Integer [ Private ]
{
    Set removed = 0
    Do ..TestLogEntries(afterId, .ids)
    Set pointer = 0
    While $ListNext(ids, pointer, id) { If $$$ISOK(##class(Ens.Util.Log).%DeleteId(id)) Set removed = removed + 1 }
    Quit removed
}

/// Rows in the task history (all namespaces).
ClassMethod HistoryRowCount() As %Integer [ Private ]
{
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM %SYS_Task.History")
    Quit $Select(result.%Next(): +result.%Get("n"), 1: 0)
}

/// Adapter settings of a production item, as "Name=Value;..." (from the class definition).
ClassMethod ProductionItem(name As %String) As %String [ Private ]
{
    Set production = ##class(Ens.Config.Production).%OpenId("MyOwn.Production.Main")
    If '$IsObject(production) Quit ""
    Set text = ""
    For index = 1:1:production.Items.Count() {
        Set item = production.Items.GetAt(index)
        If item.Name '= name Continue
        For settingIndex = 1:1:item.Settings.Count() {
            Set setting = item.Settings.GetAt(settingIndex)
            If setting.Target = "Adapter" Set text = text _ setting.Name _ "=" _ setting.Value _ ";"
        }
    }
    Quit text
}

/// Creates a task of this namespace whose every run fails; returns its id (0 on error).
ClassMethod CreateFailingTask() As %Integer [ SqlName = TestFailingTaskCreate, SqlProc ]
{
    Set namespace = $Namespace
    New $Namespace
    Set $Namespace = "%SYS"
    Set task = ##class(%SYS.Task).%New()
    Set task.Name = ..#TaskPrefix _ $ZDateTime($ZTimeStamp, 8, 1)
    Set task.Description = "Temporary task of the MyOwn Portal adapter test; it always fails."
    Set task.NameSpace = namespace
    Set task.TaskClass = "MyOwn.Test.FailingTask"
    Set task.RunAsUser = "_SYSTEM"
    Set task.TimePeriod = 5
    Set task.Suspended = 0
    Set tSC = task.%Save()
    Quit $Select($$$ISOK(tSC): task.%Id(), 1: 0)
}

/// Runs the test task once now (asynchronously, through the task manager).
ClassMethod RunFailingTask(taskId As %Integer) As %String [ SqlName = TestFailingTaskRun, SqlProc ]
{
    If '..IsTestTask(taskId) Quit "refused: not a test task"
    New $Namespace
    Set $Namespace = "%SYS"
    Set tSC = ##class(%SYS.Task).RunNow(taskId)
    Quit $Select($$$ISOK(tSC): "ok", 1: $System.Status.GetErrorText(tSC))
}

/// Failed runs of the test task in the history, and what the watcher produced for it:
/// {"failures", "messages" (IncidentEvents from TaskWatcher), "decision" {...}, "proposal" {...}}.
ClassMethod FailingTaskState(taskId As %Integer) As %String [ SqlName = TestFailingTaskState, SqlProc ]
{
    Set out = {"taskId": (+taskId), "failures": 0, "messages": 0}
    If '..IsTestTask(taskId, .name) Quit {"error": "not a test task"}.%ToJSON()
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status FROM %SYS_Task.History WHERE Name = ?", name)
    While result.%Next() { If ##class(MyOwn.Production.Adapter.TaskHistoryInbound).IsFailure(result.%Get("Status")) Set out.failures = out.failures + 1 }
    ; What a scan with the production settings hands the TaskWatcher for this task.
    Set adapter = ##class(MyOwn.Production.Adapter.TaskHistoryInbound).%New()
    Set out.adapter = {"handedOn": 0, "failures": 0}
    If $$$ISOK(adapter.Collect(.found)) {
        For index = 1:1:found.Count() {
            Set state = found.GetAt(index)
            If state.TaskId = taskId Set out.adapter = {"handedOn": 1, "failures": (state.Failures), "manageable": (state.Manageable), "namespace": (state.Namespace)}
        }
    }
    ; The task id is written as a number in context.task and as text in the candidate.
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM Ens.MessageHeader h JOIN MyOwn_Production_Msg.IncidentEvent e ON e.ID = h.MessageBodyId WHERE h.SourceConfigName = 'TaskWatcher' AND h.MessageBodyClassName = 'MyOwn.Production.Msg.IncidentEvent' AND (e.ContextJSON LIKE ? OR e.ContextJSON LIKE ?)", "%""id"":" _ (+taskId) _ ",%", "%""id"":""" _ (+taskId) _ """%")
    If result.%Next() Set out.messages = +result.%Get("n")
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 p.ID, p.Kind, p.State, d.Engine, d.Action, ev.Source, d.TraceId FROM MyOwn_Agent.Proposal p JOIN MyOwn_Agent.Decision d ON d.ID = p.DecisionId LEFT JOIN MyOwn_Agent.Event ev ON ev.ID = d.EventId WHERE p.TargetType = 'task' AND p.TargetId = ? ORDER BY p.ID DESC", +taskId)
    If result.%Next() {
        Set out.proposal = {"id": (+result.%Get("ID")), "kind": (result.%Get("Kind")), "state": (result.%Get("State"))}
        Set out.decision = {"engine": (result.%Get("Engine")), "action": (result.%Get("Action")), "eventSource": (result.%Get("Source")), "traceId": (result.%Get("TraceId"))}
    }
    Quit out.%ToJSON()
}

/// Rejects the test task's pending proposals and deletes the task.
ClassMethod RemoveFailingTask(taskId As %Integer) As %String [ SqlName = TestFailingTaskRemove, SqlProc ]
{
    If '..IsTestTask(taskId) Quit "refused: not a test task"
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM MyOwn_Agent.Proposal WHERE TargetType = 'task' AND TargetId = ? AND State = 'pending'", +taskId)
    While result.%Next() { Do ##class(MyOwn.Agent.Service.Agent).RejectProposal(result.%Get("ID"), "myown.test.adapter", "adapter test cleanup", .data) }
    New $Namespace
    Set $Namespace = "%SYS"
    Set tSC = ##class(%SYS.Task).%DeleteId(taskId)
    Quit $Select($$$ISOK(tSC): "ok", 1: $System.Status.GetErrorText(tSC))
}

ClassMethod IsTestTask(taskId As %Integer, Output name As %String) As %Boolean [ Private ]
{
    Set name = ""
    Set result = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, TaskClass FROM %SYS.Task WHERE ID = ?", +taskId)
    If 'result.%Next() Quit 0
    Set name = result.%Get("Name")
    Quit ($Extract(name, 1, $Length(..#TaskPrefix)) = ..#TaskPrefix) && (result.%Get("TaskClass") = "MyOwn.Test.FailingTask")
}

ClassMethod Add(report As %DynamicObject, id As %String, passed As %Boolean, details As %String) [ Private ]
{
    Do report.results.%Push({"id": (id), "status": ($Select(passed: "pass", 1: "fail")), "details": (details)})
    If passed {
        Set report.pass = report.pass + 1
    } Else {
        Set report.fail = report.fail + 1
    }
}

}
