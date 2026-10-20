Class MyOwn.Production.Service.LogWatcher Extends Ens.BusinessService
{

Parameter ADAPTER = "Ens.InboundAdapter";

Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Context.Logs).Recent(2, 10, .items)
    If $$$ISERR(tSC) Quit tSC
    If items.%Size() = 0 Quit $$$OK
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
