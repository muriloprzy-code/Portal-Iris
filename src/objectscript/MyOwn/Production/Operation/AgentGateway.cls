Class MyOwn.Production.Operation.AgentGateway Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";
Parameter ADAPTER = "";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="MyOwn.Production.Msg.AgentRequest">
    <Method>Decide</Method>
  </MapItem>
</MapItems>
}

/// Step 1 of the decision pipeline: engine selection, Validator and ledger.
/// The response carries the validated decision before the Gate (DecisionId and ProposalId are 0).
Method Decide(request As MyOwn.Production.Msg.AgentRequest, Output response As MyOwn.Production.Msg.AgentResponse) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).Decide(request.Workflow, request.ContextJSON, request.Source, request.TraceId, .result)
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
        Set response.ValidationStatus = result.validationStatus
    }
    Set response.TraceId = result.%Get("traceId")
    Set response.EventId = +result.%Get("eventId")
    Quit $$$OK
}

}
