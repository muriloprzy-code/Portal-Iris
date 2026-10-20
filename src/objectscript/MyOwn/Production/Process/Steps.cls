Include Ensemble

/// The decision pipeline shared by TriageProcess and AccessProcess, as three separate steps
/// that each leave a trace in the production (message or Event Log entry, keyed by TraceId):
/// 1. decide: AgentGateway (engine + Validator), 2. Gate: deterministic policy in the process,
/// 3. proposal: ProposalStore. Log lines carry only enums and ids, never model text.
Class MyOwn.Production.Process.Steps
{

ClassMethod Run(process As Ens.BusinessProcess, workflow As %String, source As %String, contextJSON As %String, traceId As %String, actor As %String, Output response As MyOwn.Production.Msg.AgentResponse) As %Status
{
    Set agentRequest = ##class(MyOwn.Production.Msg.AgentRequest).%New()
    Set agentRequest.Workflow = workflow
    Set agentRequest.Source = source
    Set agentRequest.ContextJSON = contextJSON
    Set agentRequest.TraceId = traceId
    Set agentRequest.Actor = actor
    Set tSC = process.SendRequestSync("AgentGateway", agentRequest, .decided)
    If $$$ISERR(tSC) Quit tSC
    $$$LOGINFO("[" _ traceId _ "] step 1 decide: engine=" _ decided.Engine _ " outcome=" _ decided.Outcome _ " validation=" _ decided.ValidationStatus)
    If decided.Outcome = "suppressed" {
        Set response = decided
        Quit $$$OK
    }

    Set tSC = ##class(MyOwn.Agent.Service.Agent).ApplyGate(workflow, decided.EventId, decided.Engine, decided.ValidationStatus, decided.DecisionJSON, contextJSON, traceId, actor, .gated)
    If $$$ISERR(tSC) Quit tSC
    Set gate = gated.gate
    $$$LOGINFO("[" _ traceId _ "] step 2 gate: finalAction=" _ gate.finalAction _ " allowed=" _ (+gate.allowed) _ " createProposal=" _ (+gate.createProposal) _ " downgradedBy=" _ gate.downgradedBy _ " decisionId=" _ gated.decisionId)

    Set proposalId = 0
    If gate.allowed && gate.createProposal {
        Set proposalRequest = ##class(MyOwn.Production.Msg.ProposalRequest).%New()
        Set proposalRequest.DecisionId = gated.decisionId
        Set proposalRequest.DecisionJSON = gated.decision.%ToJSON()
        Set proposalRequest.ContextJSON = contextJSON
        Set proposalRequest.TraceId = traceId
        Set tSC = process.SendRequestSync("ProposalStore", proposalRequest, .stored)
        If $$$ISERR(tSC) Quit tSC
        Set proposalId = stored.ProposalId
        $$$LOGINFO("[" _ traceId _ "] step 3 proposal: proposalId=" _ proposalId)
    } ElseIf gate.downgradedBy = "duplicate-proposal" {
        ; The same action is already pending for this target: point to it instead of creating another.
        Set proposalId = +gate.duplicateOf
        $$$LOGINFO("[" _ traceId _ "] step 3 proposal: reused pending proposalId=" _ proposalId)
    } Else {
        $$$LOGINFO("[" _ traceId _ "] step 3 proposal: none" _ $Select(gate.downgradedBy="recently-executed":" (recently executed proposalId=" _ gate.duplicateOf _ ")", 1:""))
    }

    Set response = ##class(MyOwn.Production.Msg.AgentResponse).%New()
    Set response.DecisionJSON = gated.decision.%ToJSON()
    Set response.Engine = decided.Engine
    Set response.Outcome = decided.Outcome
    Set response.TraceId = traceId
    Set response.EventId = decided.EventId
    Set response.DecisionId = gated.decisionId
    Set response.ProposalId = proposalId
    Set response.ValidationStatus = decided.ValidationStatus
    Set response.GateJSON = gate.%ToJSON()
    Quit $$$OK
}

}
