/// Demonstration Task Manager task. It stores the current Meu Portal health score
/// in ^MeuPortal.HealthSnapshot (newest 100 entries) and changes nothing else.
Class MeuPortal.Task.HealthSnapshot Extends %SYS.Task.Definition
{

Parameter TaskName = "Meu Portal health snapshot";

/// Number of snapshots kept in the global.
Parameter MaximumSnapshots = 100;

Method OnTask() As %Status
{
    Set tSC = ##class(MeuPortal.Service.HealthAnalysis).GetReport(.report)
    If $$$ISERR(tSC) Quit tSC

    Set ^MeuPortal.HealthSnapshot($ZDateTime($Horolog, 3, 1)) = report.score _ "|" _ report.status

    Set count = 0
    Set key = ""
    For {
        Set key = $Order(^MeuPortal.HealthSnapshot(key), -1)
        If key = "" Quit
        Set count = count + 1
        If count > ..#MaximumSnapshots Kill ^MeuPortal.HealthSnapshot(key)
    }
    Quit $$$OK
}

}
