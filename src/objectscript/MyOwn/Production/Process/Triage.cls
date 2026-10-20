Class MyOwn.Production.Process.Triage Extends Ens.BusinessProcess
{

Method OnRequest(request As MyOwn.Production.Msg.IncidentEvent, Output response As MyOwn.Production.Msg.AgentResponse) As %Status
{
    Set tSC = ##class(Ens.Rule.Definition).EvaluateRules("MyOwn.Production.Rule.Routing", "", request, "Route incident", .route, .reason)
    If $$$ISERR(tSC) Quit tSC
    If route = "drop" {
        Set response = ##class(MyOwn.Production.Msg.AgentResponse).%New()
        Set response.TraceId = request.TraceId
        Set response.Engine = "routing-rule"
        Set response.Outcome = "ignored"
        Set response.DecisionJSON = "{}"
        Quit $$$OK
    }
    Set agentRequest = ##class(MyOwn.Production.Msg.AgentRequest).%New()
    Set agentRequest.Workflow = route
    Set agentRequest.Source = request.Source
    Set agentRequest.ContextJSON = request.ContextJSON
    Set agentRequest.TraceId = request.TraceId
    Set tSC = ..SendRequestSync("AgentGateway", agentRequest, .response)
    If $$$ISERR(tSC) Quit tSC
    If response.Outcome = "budget_blocked" {
        Set feedback = ##class(MyOwn.Production.Msg.ExecutionFeedback).%New()
        Set feedback.ProposalId = 0
        Set feedback.State = "budget-blocked"
        Set feedback.Message = "The AI budget was exhausted. The deterministic Rules engine handled the event."
        Set feedback.TraceId = response.TraceId
        Set tSC = ..SendRequestSync("Notifier", feedback, .notificationResponse)
        If $$$ISERR(tSC) Quit tSC
    }
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
