Class MyOwn.Production.Process.Access Extends Ens.BusinessProcess
{

Method OnRequest(request As MyOwn.Production.Msg.AccessRequestEvent, Output response As MyOwn.Production.Msg.AgentResponse) As %Status
{
    Set agentRequest = ##class(MyOwn.Production.Msg.AgentRequest).%New()
    Set agentRequest.Workflow = "access-request"
    Set agentRequest.Source = "access"
    Set agentRequest.ContextJSON = request.ContextJSON
    Set agentRequest.TraceId = request.TraceId
    ; The requester is untrusted workflow context, not the human approver.
    ; Separation of duties is enforced later when a proposal is confirmed.
    Set agentRequest.Actor = ""
    Set tSC = ..SendRequestSync("AgentGateway", agentRequest, .response)
    If $$$ISERR(tSC) {
        Do ##class(MyOwn.Agent.Service.Agent).CompleteAccessRequest(request.RequestId, "", tSC)
        Quit tSC
    }
    Set tSC = ##class(MyOwn.Agent.Service.Agent).CompleteAccessRequest(request.RequestId, response)
    If $$$ISERR(tSC) Quit tSC
    If response.ProposalId {
        Set proposalRequest = ##class(MyOwn.Production.Msg.ProposalRequest).%New()
        Set proposalRequest.DecisionId = response.DecisionId
        Set proposalRequest.DecisionJSON = response.DecisionJSON
        Set proposalRequest.ContextJSON = request.ContextJSON
        Set proposalRequest.TraceId = response.TraceId
        Set tSC = ..SendRequestAsync("ProposalStore", proposalRequest, 0)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit $$$OK
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
