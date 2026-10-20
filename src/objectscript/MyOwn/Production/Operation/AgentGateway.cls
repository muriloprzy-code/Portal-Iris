Class MyOwn.Production.Operation.AgentGateway Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";
Parameter ADAPTER = "";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="MyOwn.Production.Msg.AgentRequest">
    <Method>Analyze</Method>
  </MapItem>
</MapItems>
}

Method Analyze(request As MyOwn.Production.Msg.AgentRequest, Output response As MyOwn.Production.Msg.AgentResponse) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Analyze(request.Workflow, request.ContextJSON, request.Source, request.TraceId, request.Actor, .result)
    If $$$ISERR(tSC) Quit tSC
    Set response = ##class(MyOwn.Production.Msg.AgentResponse).%New()
    If result.%Get("status") = "suppressed" {
        Set response.DecisionJSON = "{}"
        Set response.Engine = "cooldown"
        Set response.Outcome = "suppressed"
    } Else {
        Set response.DecisionJSON = result.decision.%ToJSON()
        Set response.Engine = result.engine
        Set response.Outcome = result.outcome
    }
    Set response.TraceId = result.%Get("traceId")
    Set response.EventId = +result.%Get("eventId")
    Set response.DecisionId = +result.%Get("decisionId")
    Set response.ProposalId = +result.%Get("proposalId")
    Quit $$$OK
}

}
