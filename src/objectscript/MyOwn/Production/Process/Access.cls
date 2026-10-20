Class MyOwn.Production.Process.Access Extends Ens.BusinessProcess
{

Method OnRequest(request As MyOwn.Production.Msg.AccessRequestEvent, Output response As MyOwn.Production.Msg.AgentResponse) As %Status
{
    ; decide (AgentGateway) → Gate → proposal (ProposalStore), each a visible step.
    ; The requester is untrusted workflow context, not the human approver (actor is empty);
    ; separation of duties is enforced again when a proposal is confirmed.
    Set tSC = ##class(MyOwn.Production.Process.Steps).Run($this, "access-request", "access", request.ContextJSON, request.TraceId, "", .response)
    If $$$ISERR(tSC) {
        Do ##class(MyOwn.Agent.Service.Agent).CompleteAccessRequest(request.RequestId, "", tSC)
        Quit tSC
    }
    Quit ##class(MyOwn.Agent.Service.Agent).CompleteAccessRequest(request.RequestId, response)
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
