Class MyOwn.Production.Service.HealthMonitor Extends Ens.BusinessService
{

Parameter ADAPTER = "Ens.InboundAdapter";

Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    If $IsObject(pInput) {
        If pInput.%IsA("MyOwn.Production.Msg.IncidentEvent") {
            Set tSC = ..SendRequestSync("TriageProcess", pInput, .pOutput)
            Quit tSC
        }
    }
    Set tSC = ##class(MyOwn.Agent.Context.Health).Current(.context)
    If $$$ISERR(tSC) Quit tSC
    If context.anomalies.%Size() = 0 Quit $$$OK
    Set request = ##class(MyOwn.Production.Msg.IncidentEvent).%New()
    Set request.Source = "health"
    Set request.ContextJSON = context.%ToJSON()
    Set request.TraceId = $System.Util.CreateGUID()
    Set request.Fingerprint = $ZCRC(request.ContextJSON, 7) _ ":" _ $Length(request.ContextJSON)
    Set tSC = ..SendRequestAsync("TriageProcess", request, 0)
    Quit tSC
}

}
