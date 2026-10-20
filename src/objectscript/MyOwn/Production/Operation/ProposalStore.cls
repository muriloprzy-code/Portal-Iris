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

Method Store(request As MyOwn.Production.Msg.ProposalRequest, Output response As Ens.Response) As %Status
{
    Set response = ##class(Ens.Response).%New()
    If '##class(MyOwn.Agent.Decision).%ExistsId(request.DecisionId) Quit $$$ERROR($$$GeneralError, "DECISION_NOT_FOUND")
    Quit $$$OK
}

}
