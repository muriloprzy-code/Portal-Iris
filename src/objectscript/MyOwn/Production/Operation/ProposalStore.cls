Class MyOwn.Production.Operation.ProposalStore Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";
Parameter ADAPTER = "";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="MyOwn.Production.Msg.ProposalRequest">
    <Method>Store</Method>
  </MapItem>
</MapItems>
}

/// Step 3 of the decision pipeline: creates the proposal (server-side before/after diff and
/// expiry) after re-checking the Gate on the final decision.
Method Store(request As MyOwn.Production.Msg.ProposalRequest, Output response As MyOwn.Production.Msg.ProposalResponse) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Service.Agent).StoreProposal(request.DecisionId, request.DecisionJSON, request.ContextJSON, .proposalId)
    If $$$ISERR(tSC) Quit tSC
    Set response = ##class(MyOwn.Production.Msg.ProposalResponse).%New()
    Set response.ProposalId = proposalId
    Quit $$$OK
}

}
