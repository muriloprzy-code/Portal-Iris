/// Inbound adapter of the LogWatcher service. Every CallInterval it reads the newest log entries
/// with a severity of at least MinSeverity, up to MaxEntries (MyOwn.Agent.Context.Logs.Recent, which
/// sanitizes each message), and hands the service one MyOwn.Production.Adapter.LogBatch when there
/// is at least one. A failed read is logged and retried at the next interval.
Class MyOwn.Production.Adapter.LogEntriesInbound Extends Ens.InboundAdapter
{

Parameter SERVICEINPUTCLASS = "MyOwn.Production.Adapter.LogBatch";

Parameter SETTINGS = "MinSeverity:Basic,MaxEntries:Basic";

/// Lowest severity code handed on (2 = serious; 1 = warning).
Property MinSeverity As %Integer(MAXVAL = 3, MINVAL = 0) [ InitialExpression = 2 ];

/// Window of each scan: at most this many entries, newest first (Logs.Recent caps it at 20).
Property MaxEntries As %Integer(MAXVAL = 20, MINVAL = 1) [ InitialExpression = 10 ];

/// Class whose Recent(minSeverity, limit, .data) supplies the entries. Not a setting: tests replace it.
Property SourceClass As %String [ InitialExpression = "MyOwn.Agent.Context.Logs", Internal ];

Method OnTask() As %Status
{
    Set tSC = ..Collect(.batch)
    If $$$ISERR(tSC) {
        $$$LOGSTATUS(tSC)
        Set tSC = $$$OK
    } ElseIf $IsObject(batch) {
        Set tSC = ..BusinessHost.ProcessInput(batch)
    }
    Set ..BusinessHost.%WaitForNextCallInterval = 1
    Quit tSC
}

/// One scan: a batch, or "" when there is nothing to hand on (public so tests can run it without a production).
Method Collect(Output batch As MyOwn.Production.Adapter.LogBatch) As %Status
{
    Set batch = ""
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..SourceClass, "Recent", ..MinSeverity, ..MaxEntries, .items)
        If $$$ISERR(tSC) Quit
        If items.%Size() = 0 Quit
        Set batch = ##class(MyOwn.Production.Adapter.LogBatch).%New()
        Set batch.ItemsJSON = items.%ToJSON()
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

}
