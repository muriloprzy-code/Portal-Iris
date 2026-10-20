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
    ; decide (AgentGateway) → Gate → proposal (ProposalStore), each a visible step
    Set tSC = ##class(MyOwn.Production.Process.Steps).Run($this, route, request.Source, request.ContextJSON, request.TraceId, "", .response)
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
    Quit $$$OK
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
