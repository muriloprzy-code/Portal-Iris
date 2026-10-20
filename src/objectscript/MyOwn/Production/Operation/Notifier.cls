Class MyOwn.Production.Operation.Notifier Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";
Parameter ADAPTER = "";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="MyOwn.Production.Msg.ExecutionFeedback">
    <Method>StoreFeedback</Method>
  </MapItem>
</MapItems>
}

Method StoreFeedback(request As MyOwn.Production.Msg.ExecutionFeedback, Output response As Ens.Response) As %Status
{
    Set notification = ##class(MyOwn.Agent.Notification).%New()
    Set notification.Kind = $Select(request.State="budget-blocked":"budget", 1:"execution-feedback")
    Set notification.Severity = $Select(request.State="failed":"error", request.State="budget-blocked":"warning", 1:"info")
    Set notification.Message = ##class(MyOwn.Agent.Sanitize).Text(request.Message, 1000)
    Set notification.RefType = $Select(request.State="budget-blocked":"trace", 1:"proposal")
    Set notification.RefId = $Select(request.State="budget-blocked":request.TraceId, 1:request.ProposalId)
    Set notification.CreatedAt = $ZDateTime($Horolog, 3, 1)
    Set tSC = notification.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set response = ##class(Ens.Response).%New()
    Quit $$$OK
}

}
