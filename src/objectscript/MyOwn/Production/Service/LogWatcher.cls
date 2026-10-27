Class MyOwn.Production.Service.LogWatcher Extends Ens.BusinessService
{

Parameter ADAPTER = "MyOwn.Production.Adapter.LogEntriesInbound";

/// Receives from the adapter the serious log entries of one scan (already sanitized).
Method OnProcessInput(pInput As MyOwn.Production.Adapter.LogBatch, Output pOutput As %RegisteredObject) As %Status
{
    If '$IsObject(pInput) Quit $$$OK
    Set items = [].%FromJSON(pInput.ItemsJSON)
    Set context = {}
    Set context.source = "log-watcher"
    Set context.logs = items
    Set context.candidates = []
    Set context.untrustedData = {}
    Set request = ##class(MyOwn.Production.Msg.IncidentEvent).%New()
    Set request.Source = "log"
    Set request.ContextJSON = context.%ToJSON()
    Set request.TraceId = $System.Util.CreateGUID()
    Set request.Fingerprint = $ZCRC(request.ContextJSON, 7) _ ":" _ $Length(request.ContextJSON)
    Set tSC = ..SendRequestAsync("TriageProcess", request, 0)
    Quit tSC
}

}
