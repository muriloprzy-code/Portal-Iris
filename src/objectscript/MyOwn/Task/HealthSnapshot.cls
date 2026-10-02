/// Demonstration Task Manager task. It stores the current MyOwn Portal health score
/// and metrics in ^MyOwn.HealthSnapshot (newest 100 entries) and changes nothing else.
/// The stored metrics feed MyOwn.Service.HealthAnalysis's anomaly detector (the
/// "AI-Powered Instance Monitor", implementing community idea DPI-I-512).
Class MyOwn.Task.HealthSnapshot Extends %SYS.Task.Definition
{

Parameter TaskName = "MyOwn Portal health snapshot";

/// Number of snapshots kept in the global.
Parameter MaximumSnapshots = 100;

Method OnTask() As %Status
{
    Set tSC = ##class(MyOwn.Service.HealthAnalysis).GetReport(.report)
    If $$$ISERR(tSC) Quit tSC

    // Entry format: score|status|diskUsedPercent|databaseSpacePercent|lockTablePercent|seriousAlerts|processes
    Set entry = report.score _ "|" _ report.status
    Set entry = entry _ "|" _ report.metrics.diskUsedPercent
    Set entry = entry _ "|" _ report.metrics.databaseSpacePercent
    Set entry = entry _ "|" _ report.metrics.lockTablePercent
    Set entry = entry _ "|" _ report.metrics.seriousAlerts
    Set entry = entry _ "|" _ report.metrics.processes
    Set ^MyOwn.HealthSnapshot($ZDateTime($Horolog, 3, 1)) = entry

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
