/// Demonstration Task Manager task. It stores the current MyOwn Portal health score
/// in ^MyOwn.HealthSnapshot (newest 100 entries) and changes nothing else.
Class MyOwn.Task.HealthSnapshot Extends %SYS.Task.Definition
{

Parameter TaskName = "MyOwn Portal health snapshot";

/// Number of snapshots kept in the global.
Parameter MaximumSnapshots = 100;

Method OnTask() As %Status
{
    Set tSC = ##class(MyOwn.Service.HealthAnalysis).GetReport(.report)
    If $$$ISERR(tSC) Quit tSC

    Set ^MyOwn.HealthSnapshot($ZDateTime($Horolog, 3, 1)) = report.score _ "|" _ report.status

    Set count = 0
    Set key = ""
    For {
        Set key = $Order(^MyOwn.HealthSnapshot(key), -1)
        If key = "" Quit
        Set count = count + 1
        If count > ..#MaximumSnapshots Kill ^MyOwn.HealthSnapshot(key)
    }
    Quit $$$OK
}

}
