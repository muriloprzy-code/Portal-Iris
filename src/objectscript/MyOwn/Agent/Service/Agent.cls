Class MyOwn.Agent.Service.Agent
{

ClassMethod Status(Output data As %DynamicObject) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Config).PublicView(.config)
    If $$$ISERR(tSC) Quit tSC
    Set data = config
    Set data.aiHubAvailable = ##class(%Dictionary.CompiledClass).%ExistsId("MyOwn.AIHub.Engine")
    Set data.activeEngine = $Select((config.enginePreference'="rules")&&data.aiHubAvailable:"aihub", 1:"rules")
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.configObject)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Agent.Policy.Budget).Evaluate(configObject, 0, .budget)
    If $$$ISERR(tSC) Quit tSC
    Set data.tokensUsedToday = budget.usedToday
    Set data.dailyTokenBudget = configObject.DailyTokenBudget
    Set data.production = {}
    Set data.production.name = "MyOwn.Production.Main"
    Set data.production.running = (##class(Ens.Director).GetActiveProductionName() = "MyOwn.Production.Main")
    Quit $$$OK
}

/// Thin facade for a manual incident analysis. The work happens in the production:
/// HealthMonitor → TriageProcess → AgentGateway (decide) → Gate → ProposalStore.
/// The response keeps its previous shape (decision, gate, proposalId, status when suppressed).
ClassMethod Analyze(workflow As %String, contextJSON As %String, source As %String = "manual", traceId As %String = "", actor As %String = "", Output response As %DynamicObject) As %Status
{
    Set response = {}
    If workflow '= "incident-triage" Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set parseStatus = $$$OK
    Try {
        Set context = {}.%FromJSON(contextJSON)
    } Catch exception {
        Set parseStatus = exception.AsStatus()
    }
    If $$$ISERR(parseStatus) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set event = ##class(MyOwn.Production.Msg.IncidentEvent).%New()
    Set event.Source = source
    Set event.ContextJSON = contextJSON
    Set event.TraceId = $Select(traceId'="":traceId, 1:$System.Util.CreateGUID())
    Set event.Fingerprint = ..Fingerprint(..StableKey(workflow, context))
    Set tSC = ##class(Ens.Director).CreateBusinessService("HealthMonitor", .service)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = service.ProcessInput(event, .message)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(message) Quit $$$ERROR($$$GeneralError, "AGENT_RESPONSE_MISSING")
    Set response = ..ResponseFromMessage(message)
    Quit $$$OK
}

/// Production step 1 (AgentGateway): cooldown, event, engine selection, Validator and ledger.
/// Returns the validated, sanitized decision before the Gate; nothing is proposed here.
ClassMethod Decide(workflow As %String, contextJSON As %String, source As %String, traceId As %String, Output result As %DynamicObject) As %Status
{
    Set result = {}
    Set started = $ZDateTime($Horolog, 3, 1)
    Set startSeconds = $Piece($Horolog, ",", 2)
    If traceId = "" Set traceId = $System.Util.CreateGUID()
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit tSC
    Set parseStatus = $$$OK
    Try {
        Set context = {}.%FromJSON(contextJSON)
    } Catch exception {
        Set parseStatus = exception.AsStatus()
    }
    If $$$ISERR(parseStatus) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set fingerprint = ..Fingerprint(..StableKey(workflow, context))
    Set tSC = ##class(MyOwn.Agent.Policy.Gate).CheckCooldown(fingerprint, config, .suppressed)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..SaveEvent(workflow, source, fingerprint, contextJSON, traceId, $Select(suppressed:"suppressed", 1:"new"), .eventId)
    If $$$ISERR(tSC) Quit tSC
    If suppressed {
        Set result.traceId = traceId
        Set result.eventId = eventId
        Set result.status = "suppressed"
        Quit $$$OK
    }

    Set engine = "rules"
    Set outcome = "ok"
    Set useAIHub = 0
    If 'config.KillSwitch, config.EnginePreference '= "rules", ##class(%Dictionary.CompiledClass).%ExistsId("MyOwn.AIHub.Engine") {
        Set tSC = ##class(MyOwn.Agent.Policy.Budget).Evaluate(config, config.PerDecisionTokenBudget, .budget)
        If $$$ISERR(tSC) Quit tSC
        Set tSC = ##class(MyOwn.Agent.Policy.Budget).CallsAllowed(config, .callsAllowed, .recentCalls)
        If $$$ISERR(tSC) Quit tSC
        If budget.allowed && callsAllowed Set useAIHub = 1
        If 'budget.allowed Set outcome = "budget_blocked"
        If 'callsAllowed Set outcome = "fallback"
    }
    If (source = "simulate") && context.%Get("budgetScenario") {
        Set useAIHub = 0
        Set outcome = "budget_blocked"
    }
    If config.KillSwitch Set outcome = "killed"

    Set tSC = $$$OK
    If useAIHub {
        Set engine = "aihub"
        Set tSC = $ClassMethod("MyOwn.AIHub.Engine", "Decide", workflow, contextJSON, .engineResult)
        If $$$ISERR(tSC) {
            Set engine = "rules"
            Set outcome = "fallback"
        }
    }
    If engine = "rules" Set tSC = ##class(MyOwn.Agent.Engine.Rules).Decide(workflow, contextJSON, .engineResult)
    If $$$ISERR(tSC) Quit tSC

    Set rawDecision = engineResult.decision.%ToJSON()
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate(workflow, rawDecision, contextJSON, .decision, .validationErrors)
    If $$$ISERR(tSC) {
        Set decision = ..EscalationDecision(workflow, context, validationErrors)
        Set validationStatus = "rejected"
        Set outcome = "error"
    } Else {
        Set validationStatus = "valid"
    }
    // From here on only the sanitized form is used: stored, sent through the production and returned.
    Set decision = ..PublicDecision(decision)
    Set duration = ($Piece($Horolog, ",", 2) - startSeconds) * 1000
    If duration < 0 Set duration = duration + 86400000
    Set tSC = ..SaveLedger(traceId, workflow, engine, engineResult, started, duration, outcome, .ledgerId)
    If $$$ISERR(tSC) Quit tSC
    Set result.traceId = traceId
    Set result.eventId = eventId
    Set result.engine = engine
    Set result.outcome = outcome
    Set result.validationStatus = validationStatus
    Set result.decision = decision
    Quit $$$OK
}

/// Production step 2 (business process): the deterministic Gate on the validated decision,
/// then the decision record with the final action and the downgrade reason.
ClassMethod ApplyGate(workflow As %String, eventId As %Integer, engine As %String, validationStatus As %String, decisionJSON As %String, contextJSON As %String, traceId As %String, actor As %String, Output result As %DynamicObject) As %Status
{
    Set result = {}
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit tSC
    Set parseStatus = $$$OK
    Try {
        Set decision = {}.%FromJSON(decisionJSON)
        Set context = {}.%FromJSON(contextJSON)
    } Catch exception {
        Set parseStatus = exception.AsStatus()
    }
    If $$$ISERR(parseStatus) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set tSC = ##class(MyOwn.Agent.Policy.Gate).Evaluate(decision, context, config, actor, .gate)
    If $$$ISERR(tSC) Quit tSC
    Set decision.action = gate.finalAction
    ; Never a second proposal for the same target and action (pending, or executed within the cooldown).
    If gate.allowed && gate.createProposal {
        Set tSC = ..ResolveDuplicate(decision, context, config, .existingId, .duplicateReason, .duplicateMessage)
        If $$$ISERR(tSC) Quit tSC
        If existingId {
            Set gate.createProposal = 0
            Set gate.downgradedBy = duplicateReason
            Set gate.duplicateOf = existingId
            Set gate.reason = duplicateMessage
        }
    }
    Set decision = ..PublicDecision(decision)
    Set tSC = ..SaveDecision(eventId, workflow, engine, decision, validationStatus, gate, config, traceId, .decisionId)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("Decision", decisionId, workflow _ "/" _ gate.finalAction, 1, engine _ "/" _ validationStatus _ "/" _ $Select(gate.downgradedBy'="":gate.downgradedBy, 1:"none"))
    If $$$ISERR(tSC) Quit tSC
    Set result.decisionId = decisionId
    Set result.decision = decision
    Set result.gate = gate
    Quit $$$OK
}

/// Production step 3 (ProposalStore): creates the proposal for a gated decision. The Gate is
/// evaluated again on the final decision, so a message can never create what the Gate refuses.
ClassMethod StoreProposal(decisionId As %Integer, decisionJSON As %String, contextJSON As %String, Output proposalId As %Integer) As %Status
{
    Set proposalId = 0
    If '##class(MyOwn.Agent.Decision).%ExistsId(decisionId) Quit $$$ERROR($$$GeneralError, "DECISION_NOT_FOUND")
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit tSC
    Set parseStatus = $$$OK
    Try {
        Set decision = {}.%FromJSON(decisionJSON)
        Set context = {}.%FromJSON(contextJSON)
    } Catch exception {
        Set parseStatus = exception.AsStatus()
    }
    If $$$ISERR(parseStatus) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set tSC = ##class(MyOwn.Agent.Policy.Gate).Evaluate(decision, context, config, "", .gate)
    If $$$ISERR(tSC) Quit tSC
    If 'gate.allowed || 'gate.createProposal || (gate.finalAction '= decision.%Get("action")) Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")
    ; Checked again here: two processes may have passed the Gate step for the same target.
    Set tSC = ..ResolveDuplicate(decision, context, config, .existingId, .duplicateReason)
    If $$$ISERR(tSC) Quit tSC
    If existingId {
        Set proposalId = $Select(duplicateReason="duplicate-proposal":existingId, 1:0)
        Quit $$$OK
    }
    Set tSC = ..CreateProposal(decisionId, decision, context, config, .proposalId)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(MyOwn.Service.Audit).RecordAgent("ProposalCreated", decisionId, "proposal " _ proposalId, 1, decision.%Get("action"))
}

ClassMethod SubmitAccessRequest(role As %String, justification As %String, authorization As %String, requester As %String, Output response As %DynamicObject) As %Status
{
    Set role = ##class(MyOwn.Agent.Sanitize).Identifier(role)
    Set justification = ##class(MyOwn.Agent.Sanitize).Text(justification, 500)
    If (role = "") || (justification = "") Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    ; The privilege delta is computed here, with the requester's own forwarded credentials,
    ; so no credential ever enters a production message.
    Set tSC = ##class(MyOwn.Agent.Context.Access).ComparePrivileges(requester, role, authorization, .context)
    If $$$ISERR(tSC) Quit tSC
    Set context.untrustedData.justification = justification
    Set tSC = ..EnqueueAccessRequest(requester, role, justification, context, .requestId)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..AccessRequestDetail(requestId, requester, 0, .response)
    Quit tSC
}

/// Persists the request as queued and hands it to the production asynchronously.
/// The decision is recorded later by AccessProcess through CompleteAccessRequest.
ClassMethod EnqueueAccessRequest(requester As %String, role As %String, justification As %String, context As %DynamicObject, Output requestId As %Integer) As %Status
{
    Set request = ##class(MyOwn.Agent.AccessRequest).%New()
    Set request.Requester = requester
    Set request.RoleRequested = role
    Set request.Justification = justification
    Set request.Status = "queued"
    Set request.TraceId = $System.Util.CreateGUID()
    Set request.CreatedAt = $ZDateTime($Horolog, 3, 1)
    Set tSC = request.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set requestId = request.%Id()
    Set context.requestId = requestId
    Set accessEvent = ##class(MyOwn.Production.Msg.AccessRequestEvent).%New()
    Set accessEvent.RequestId = requestId
    Set accessEvent.Requester = requester
    Set accessEvent.RoleRequested = role
    Set accessEvent.ContextJSON = context.%ToJSON()
    Set accessEvent.TraceId = request.TraceId
    Set tSC = ##class(Ens.Director).CreateBusinessService("AccessRequestService", .service)
    If $$$ISERR(tSC) Quit ..FailAccessRequest(request, tSC)
    Set tSC = service.ProcessInput(accessEvent)
    If $$$ISERR(tSC) Quit ..FailAccessRequest(request, tSC)
    Quit $$$OK
}

ClassMethod FailAccessRequest(request As MyOwn.Agent.AccessRequest, failure As %Status) As %Status [ Private ]
{
    Set request.Status = "failed"
    Set request.Outcome = "error"
    Set request.DecidedAt = $ZDateTime($Horolog, 3, 1)
    Do request.%Save()
    Quit failure
}

/// Called by AccessProcess when the decision for <var>requestId</var> is ready (or failed).
ClassMethod CompleteAccessRequest(requestId As %Integer, agentResponse As MyOwn.Production.Msg.AgentResponse, failure As %Status = {$$$OK}) As %Status
{
    Set request = ##class(MyOwn.Agent.AccessRequest).%OpenId(requestId, 4)
    If '$IsObject(request) Quit $$$ERROR($$$GeneralError, "ACCESS_REQUEST_NOT_FOUND")
    If $$$ISERR(failure) || '$IsObject(agentResponse) Quit ..FailAccessRequest(request, failure)
    Set request.DecisionId = agentResponse.DecisionId
    Set request.ProposalId = agentResponse.ProposalId
    Set request.Engine = agentResponse.Engine
    Set request.Outcome = agentResponse.Outcome
    Set request.Status = $Select(agentResponse.Outcome="suppressed":"suppressed", 1:"decided")
    Set request.DecidedAt = $ZDateTime($Horolog, 3, 1)
    Quit request.%Save()
}

/// Waits (polling, at most <var>timeoutSeconds</var>) until the production has finished
/// the request. Used only by the demo simulation; the REST submission never waits.
ClassMethod WaitForAccessRequest(requestId As %Integer, timeoutSeconds As %Integer = 15, Output finished As %Boolean) As %Status
{
    Set finished = 0
    For attempt = 1:1:(timeoutSeconds * 10) {
        Set status = ##class(MyOwn.Agent.AccessRequest).StatusGetStored(requestId)
        If (status '= "queued") && (status '= "") Set finished = 1  Quit
        Hang 0.1
    }
    Quit $$$OK
}

/// Request plus its decision. Requesters see only their own requests unless <var>includeAll</var>.
ClassMethod AccessRequestDetail(requestId As %Integer, actor As %String, includeAll As %Boolean, Output data As %DynamicObject) As %Status
{
    Set request = ##class(MyOwn.Agent.AccessRequest).%OpenId(+requestId)
    If '$IsObject(request) Quit $$$ERROR($$$GeneralError, "ACCESS_REQUEST_NOT_FOUND")
    If 'includeAll && ($ZConvert(request.Requester, "U") '= $ZConvert(actor, "U")) Quit $$$ERROR($$$GeneralError, "ACCESS_REQUEST_NOT_FOUND")
    Set data = ..AccessRequestView(request, 1)
    Quit $$$OK
}

ClassMethod AccessRequestView(request As MyOwn.Agent.AccessRequest, detail As %Boolean = 0) As %DynamicObject [ Private ]
{
    Set item = {}
    Set item.id = request.%Id()
    Set item.requester = request.Requester
    Set item.roleRequested = request.RoleRequested
    Set item.justification = ##class(MyOwn.Agent.Sanitize).Text(request.Justification, 500)
    Set item.status = request.Status
    Set item.traceId = request.TraceId
    Set item.decisionId = request.DecisionId
    Set item.proposalId = request.ProposalId
    Set item.engine = request.Engine
    Set item.outcome = request.Outcome
    Set item.createdAt = request.CreatedAt
    Set item.decidedAt = request.DecidedAt
    Set decision = $Select(request.DecisionId:##class(MyOwn.Agent.Decision).%OpenId(request.DecisionId), 1:"")
    If $IsObject(decision) {
        Set item.recommendation = decision.Action
        Set item.riskLevel = decision.RiskLevel
        If detail Set item.decision = ..DecisionView(decision, 1)
    }
    Quit item
}

ClassMethod SaveEvent(workflow As %String, source As %String, fingerprint As %String, contextJSON As %String, traceId As %String, status As %String, Output id As %Integer) As %Status [ Private ]
{
    Set event = ##class(MyOwn.Agent.Event).%New()
    Set event.Workflow = workflow
    Set event.Source = source
    Set event.Fingerprint = fingerprint
    Set event.PayloadJSON = ##class(%Stream.GlobalCharacter).%New()
    Do event.PayloadJSON.Write(##class(MyOwn.Agent.Sanitize).JSON(contextJSON, 32000))
    Set event.ReceivedAt = $ZDateTime($Horolog, 3, 1)
    Set event.TraceId = traceId
    Set event.Status = status
    Set tSC = event.%Save()
    If $$$ISOK(tSC) Set id = event.%Id()
    Quit tSC
}

ClassMethod SaveDecision(eventId As %Integer, workflow As %String, engine As %String, value As %DynamicObject, validationStatus As %String, gate As %DynamicObject, config As MyOwn.Agent.Config, traceId As %String, Output id As %Integer) As %Status [ Private ]
{
    Set decision = ##class(MyOwn.Agent.Decision).%New()
    Set decision.EventId = eventId
    Set decision.Workflow = workflow
    Set decision.Engine = engine
    Set decision.Action = value.%Get("action")
    Set decision.Severity = value.%Get("severity")
    Set decision.RiskLevel = value.%Get("riskLevel")
    Set decision.TargetType = value.%Get("targetType")
    Set decision.TargetId = value.%Get("targetId")
    If workflow = "access-request" {
        Set decision.TargetType = "role"
        Set decision.TargetId = value.%Get("role")
    }
    Set decision.Rationale = ##class(MyOwn.Agent.Sanitize).Text(value.%Get("rationale"), 600)
    Set decision.Confidence = value.%Get("confidence")
    Set decision.EvidenceJSON = ##class(%Stream.GlobalCharacter).%New()
    If $IsObject(value.%Get("evidence")) Do decision.EvidenceJSON.Write(..SanitizeEvidence(value.evidence).%ToJSON())
    If value.%IsDefined("conditions") Set decision.ConditionsJSON = ..PublicDecision({"conditions":(value.%Get("conditions"))}).conditions.%ToJSON()
    Set decision.ValidationStatus = validationStatus
    Set decision.DowngradedBy = gate.downgradedBy
    Set decision.GateJSON = gate.%ToJSON()
    Set decision.Autonomy = $Select(workflow="access-request":config.AutonomyAccess, 1:config.AutonomyTriage)
    Set decision.AppliedAutomatically = 0
    Set decision.TraceId = traceId
    Set decision.DecidedAt = $ZDateTime($Horolog, 3, 1)
    Set tSC = decision.%Save()
    If $$$ISOK(tSC) Set id = decision.%Id()
    Quit tSC
}

/// Evidence comes from the model, so only source and ref are kept and both are
/// sanitized before persistence. No side effects, so the adversarial corpus can test it.
ClassMethod SanitizeEvidence(evidence As %DynamicArray) As %DynamicArray
{
    Set clean = []
    For index = 0:1:(evidence.%Size() - 1) {
        Set item = evidence.%Get(index)
        If '$IsObject(item) Continue
        Set entry = {}
        Set entry.source = ##class(MyOwn.Agent.Sanitize).Identifier(item.%Get("source"), 40)
        Set entry.ref = ##class(MyOwn.Agent.Sanitize).Text(item.%Get("ref"), 200)
        Do clean.%Push(entry)
    }
    Quit clean
}

/// Returns a copy of a decision with every model-written text field sanitized exactly as
/// it is stored (rationale, recommendedFollowUp, conditions, evidence). Fields that are
/// absent stay absent, and applying it twice changes nothing.
ClassMethod PublicDecision(decision As %DynamicObject) As %DynamicObject
{
    If '$IsObject(decision) || 'decision.%IsA("%DynamicObject") Quit {}
    Set clean = {}.%FromJSON(decision.%ToJSON())
    If clean.%IsDefined("rationale") Set clean.rationale = ##class(MyOwn.Agent.Sanitize).Text(clean.%Get("rationale"), 600)
    If clean.%IsDefined("recommendedFollowUp") Set clean.recommendedFollowUp = ##class(MyOwn.Agent.Sanitize).Text(clean.%Get("recommendedFollowUp"), 300)
    If clean.%IsDefined("evidence") Set clean.evidence = ..SanitizeEvidence($Select(clean.%GetTypeOf("evidence")="array":clean.evidence, 1:[]))
    If clean.%IsDefined("conditions") {
        Set conditions = []
        If clean.%GetTypeOf("conditions") = "array" {
            For index = 0:1:(clean.conditions.%Size() - 1) {
                Do conditions.%Push(##class(MyOwn.Agent.Sanitize).Text(clean.conditions.%Get(index), 200))
            }
        }
        Set clean.conditions = conditions
    }
    Quit clean
}

/// Server-side state of the target before the proposed change; its fingerprint is what
/// ConfirmProposal compares with a fresh read of the target (TARGET_CHANGED).
ClassMethod ProposalBefore(decision As %DynamicObject, context As %DynamicObject) As %DynamicObject [ Private ]
{
    If decision.%Get("workflow") = "access-request" {
        Set before = {}
        Set before.user = decision.%Get("user")
        Set before.roles = context.%Get("currentRoles")
        Quit before
    }
    Quit ..TaskState(context.%Get("task"))
}

/// Fingerprint a proposal for this decision would carry (side-effect free).
ClassMethod ProposalFingerprint(decision As %DynamicObject, context As %DynamicObject) As %String
{
    Quit ..Fingerprint(..ProposalBefore(decision, context).%ToJSON())
}

/// Gate deduplication with stale-proposal handling: a pending proposal for the same target and
/// action is reused only while it can still be confirmed (same target fingerprint). A pending
/// proposal whose target changed is superseded (expired and audited) so a fresh one can be made.
ClassMethod ResolveDuplicate(decision As %DynamicObject, context As %DynamicObject, config As MyOwn.Agent.Config, Output existingId As %Integer, Output reason As %String, Output message As %String) As %Status [ Private ]
{
    Do ..ProposalTarget(decision, .kind, .targetType, .targetId)
    Set currentFingerprint = ..ProposalFingerprint(decision, context)
    Set tSC = $$$OK
    For attempt = 1:1:50 {
        Set tSC = ##class(MyOwn.Agent.Policy.Gate).CheckDuplicate(kind, targetType, targetId, config, .existingId, .reason, .message)
        If $$$ISERR(tSC) || 'existingId || (reason '= "duplicate-proposal") Quit
        Set existing = ##class(MyOwn.Agent.Proposal).%OpenId(existingId)
        If '$IsObject(existing) || (existing.Fingerprint = currentFingerprint) Quit
        Lock +^MyOwn.Agent.Lock("proposal", existingId):2
        If '$Test Quit
        Try {
            Set existing = ##class(MyOwn.Agent.Proposal).%OpenId(existingId)
            If existing.State = "pending" {
                Set existing.State = "expired"
                Set existing.ResolvedAt = $ZDateTime($Horolog, 3, 1)
                Set existing.ResultMessage = "Superseded: the target changed after this proposal was created."
                Set tSC = existing.%Save()
                If $$$ISOK(tSC) Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ProposalExpired", existing.DecisionId, "proposal " _ existingId, 1, "superseded")
            }
        } Catch exception {
            Set tSC = exception.AsStatus()
        }
        Lock -^MyOwn.Agent.Lock("proposal", existingId)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// The proposal a decision would produce: kind and target, as stored on MyOwn.Agent.Proposal.
ClassMethod ProposalTarget(decision As %DynamicObject, Output kind As %String, Output targetType As %String, Output targetId As %String) As %Status [ Private ]
{
    If decision.%Get("workflow") = "access-request" {
        Set kind = "role.assign"
        Set targetType = "user-role"
        Set targetId = decision.%Get("user") _ "|" _ decision.%Get("role")
    } Else {
        Set kind = $Replace($Replace(decision.%Get("action"), "propose_", ""), "task_", "task.")
        Set targetType = "task"
        Set targetId = decision.%Get("targetId")
    }
    Quit $$$OK
}

ClassMethod CreateProposal(decisionId As %Integer, decision As %DynamicObject, context As %DynamicObject, config As MyOwn.Agent.Config, Output id As %Integer) As %Status [ Private ]
{
    Set proposal = ##class(MyOwn.Agent.Proposal).%New()
    Set proposal.DecisionId = decisionId
    Do ..ProposalTarget(decision, .kind, .targetType, .targetId)
    Set proposal.Kind = kind
    Set proposal.TargetType = targetType
    Set proposal.TargetId = targetId
    Set before = ..ProposalBefore(decision, context)
    If decision.%Get("workflow") = "access-request" {
        Set after = {}
        Set after.user = decision.%Get("user")
        Set after.roleToAssign = decision.%Get("role")
        Set proposal.RequiredPrivilege = "%Admin_Secure"
        Set proposal.UndoHint = "Remove the assigned role from the user in Permissions."
    } Else {
        Set after = {}.%FromJSON(before.%ToJSON())
        If proposal.Kind = "task.suspend" Set after.suspended = 1
        If proposal.Kind = "task.resume" Set after.suspended = 0
        Set proposal.RequiredPrivilege = "%Admin_Task"
        Set proposal.UndoHint = "Reverse the task action from the Tasks page if needed."
    }
    Set beforeJSON = before.%ToJSON()
    Set afterJSON = after.%ToJSON()
    Set proposal.BeforeJSON = ##class(%Stream.GlobalCharacter).%New()
    Do proposal.BeforeJSON.Write(beforeJSON)
    Set proposal.AfterJSON = ##class(%Stream.GlobalCharacter).%New()
    Do proposal.AfterJSON.Write(afterJSON)
    Set proposal.Fingerprint = ..Fingerprint(beforeJSON)
    Set proposal.State = "pending"
    Set proposal.CreatedAt = $ZDateTime($Horolog, 3, 1)
    Set proposal.ExpiresAt = ..AddMinutes(config.ProposalTTLMinutes)
    Set tSC = proposal.%Save()
    If $$$ISOK(tSC) Set id = proposal.%Id()
    Quit tSC
}

ClassMethod SaveLedger(traceId As %String, workflow As %String, engine As %String, engineResult As %DynamicObject, started As %TimeStamp, duration As %Integer, outcome As %String, Output id As %Integer) As %Status [ Private ]
{
    Set ledger = ##class(MyOwn.Agent.Ledger).%New()
    Set ledger.TraceId = traceId
    Set ledger.Workflow = workflow
    Set ledger.Engine = engine
    Set ledger.Provider = engineResult.%Get("provider")
    Set ledger.Model = engineResult.%Get("model")
    Set ledger.StartedAt = started
    Set ledger.DurationMs = duration
    Set usage = engineResult.%Get("usage")
    If $IsObject(usage) {
        Set ledger.PromptTokens = usage.%Get("promptTokens")
        Set ledger.CompletionTokens = usage.%Get("completionTokens")
        Set ledger.TotalTokens = usage.%Get("totalTokens")
    }
    Set calls = engineResult.%Get("toolCalls")
    If $IsObject(calls) Set ledger.ToolCallCount = calls.%Size()
    Set ledger.Outcome = outcome
    Set tSC = ##class(MyOwn.Agent.Pricing).Estimate(ledger.Model, ledger.PromptTokens, ledger.CompletionTokens, .cost, .hasPrice)
    If $$$ISERR(tSC) Quit tSC
    If hasPrice Set ledger.CostEstimateUSD = cost
    Set tSC = ledger.%Save()
    If $$$ISOK(tSC) Set id = ledger.%Id()
    Quit tSC
}

ClassMethod EscalationDecision(workflow As %String, context As %DynamicObject, errors As %DynamicArray) As %DynamicObject [ Private ]
{
    Set decision = {}
    Set decision.schemaVersion = 1
    Set decision.workflow = workflow
    Set decision.action = "escalate"
    Set decision.rationale = "The generated response failed deterministic validation and requires administrator review."
    Set decision.confidence = 0
    Set decision.evidence = []
    If workflow = "access-request" {
        Set decision.riskLevel = "high"
        Set decision.user = context.%Get("requester")
        Set decision.role = context.%Get("roleRequested")
        Set decision.conditions = []
    } Else {
        Set decision.severity = "warning"
        Set decision.targetType = "none"
        Set decision.targetId = ""
        Set decision.recommendedFollowUp = "Inspect the validation errors and source event."
    }
    Quit decision
}

/// Chave estavel do incidente: ignora metricas volateis (valores, z-scores, timestamps)
/// para que o cooldown realmente deduplique o mesmo problema.
/// Band of consecutive failures used in the stable key, so every new failure of an already
/// failing task does not produce a new key (and a new event). 3 is the TaskWatcher threshold.
ClassMethod FailureBand(failures As %Integer) As %String [ Private ]
{
    Set failures = +failures
    Quit $Select(failures >= 3:"3+", failures >= 1:"1-2", 1:"0")
}

/// Public and side-effect free so the smoke tests can check that the key is stable.
ClassMethod StableKey(workflow As %String, context As %DynamicObject) As %String
{
    Set key = workflow
    Set runId = context.%Get("simulationRunId")
    If runId '= "" Quit key _ "|run:" _ runId
    If workflow = "access-request" Quit key _ "|" _ $ZConvert(context.%Get("requester"), "U") _ "|" _ context.%Get("roleRequested")
    Set anomalies = context.%Get("anomalies")
    If $IsObject(anomalies) {
        For index = 0:1:(anomalies.%Size() - 1) {
            Set item = anomalies.%Get(index)
            If $IsObject(item) Set key = key _ "|a:" _ item.%Get("metric") _ ":" _ item.%Get("severity")
        }
    }
    Set candidates = context.%Get("candidates")
    If $IsObject(candidates) {
        For index = 0:1:(candidates.%Size() - 1) {
            Set item = candidates.%Get(index)
            If $IsObject(item) Set key = key _ "|c:" _ item.%Get("type") _ ":" _ item.%Get("id")
        }
    }
    Set task = context.%Get("task")
    If $IsObject(task) Set key = key _ "|t:" _ task.%Get("id") _ ":" _ (+task.%Get("suspended")) _ ":" _ ..FailureBand(task.%Get("consecutiveFailures"))
    Set key = key _ "|th:" _ context.%Get("thresholdMetric") _ ":" _ context.%Get("thresholdSeverity")
    Set logs = context.%Get("logs")
    If $IsObject(logs) {
        For index = 0:1:(logs.%Size() - 1) {
            Set item = logs.%Get(index)
            If $IsObject(item) Set key = key _ "|l:" _ item.%Get("severityCode") _ ":" _ $ZCRC($Extract(item.%Get("message"), 1, 80), 7)
        }
    }
    Quit key
}

ClassMethod Fingerprint(value As %String) As %String [ Private ]
{
    Quit $ZCRC(value, 7) _ ":" _ $Length(value)
}

ClassMethod AddMinutes(minutes As %Integer) As %TimeStamp [ Private ]
{
    Set days = $Piece($Horolog, ",", 1)
    Set seconds = $Piece($Horolog, ",", 2) + (minutes * 60)
    Set days = days + (seconds \ 86400)
    Set seconds = seconds # 86400
    Quit $ZDateTime(days _ "," _ seconds, 3, 1)
}

ClassMethod ListDecisions(Output items As %DynamicArray) As %Status
{
    Set items = []
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 100 ID FROM MyOwn_Agent.Decision ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute()
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set decision = ##class(MyOwn.Agent.Decision).%OpenId(result.%Get("ID"))
        If $IsObject(decision) Do items.%Push(..DecisionView(decision, 0))
    }
    Quit $$$OK
}

ClassMethod DecisionDetail(id As %Integer, Output data As %DynamicObject) As %Status
{
    Set decision = ##class(MyOwn.Agent.Decision).%OpenId(id)
    If '$IsObject(decision) Quit $$$ERROR($$$GeneralError, "DECISION_NOT_FOUND")
    Set data = ..DecisionView(decision, 1)
    Set data.proposalId = ""
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 1 ID FROM MyOwn_Agent.Proposal WHERE DecisionId = ? ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(id)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    If result.%Next() Set data.proposalId = result.%Get("ID")
    Quit $$$OK
}

ClassMethod ListProposals(state As %String = "", Output items As %DynamicArray) As %Status
{
    Set items = []
    Set state = $ZConvert(##class(MyOwn.Agent.Sanitize).Identifier(state), "L")
    Set tSC = ##class(MyOwn.Agent.Proposal).ExpireOverdue(.expiredCount)
    If $$$ISERR(tSC) Quit tSC
    Set statement = ##class(%SQL.Statement).%New()
    If state = "" {
        Set tSC = statement.%Prepare("SELECT TOP 100 ID FROM MyOwn_Agent.Proposal ORDER BY ID DESC")
        If $$$ISERR(tSC) Quit tSC
        Set result = statement.%Execute()
    } Else {
        Set tSC = statement.%Prepare("SELECT TOP 100 ID FROM MyOwn_Agent.Proposal WHERE State = ? ORDER BY ID DESC")
        If $$$ISERR(tSC) Quit tSC
        Set result = statement.%Execute(state)
    }
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set proposal = ##class(MyOwn.Agent.Proposal).%OpenId(result.%Get("ID"))
        If $IsObject(proposal) Do items.%Push(..ProposalView(proposal))
    }
    Quit $$$OK
}

ClassMethod RejectProposal(id As %Integer, actor As %String, reason As %String, Output data As %DynamicObject) As %Status
{
    Lock +^MyOwn.Agent.Lock("proposal", id):5
    If '$Test Quit $$$ERROR($$$GeneralError, "PROPOSAL_BUSY")
    Set tSC = $$$OK
    Try {
        Set tSC = ..RejectProposalLocked(id, actor, reason, .data)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Lock -^MyOwn.Agent.Lock("proposal", id)
    Quit tSC
}

ClassMethod RejectProposalLocked(id As %Integer, actor As %String, reason As %String, Output data As %DynamicObject) As %Status [ Private ]
{
    Set proposal = ##class(MyOwn.Agent.Proposal).%OpenId(id)
    If '$IsObject(proposal) Quit $$$ERROR($$$GeneralError, "PROPOSAL_NOT_FOUND")
    Set reason = ##class(MyOwn.Agent.Sanitize).Text(reason, 500)
    Set tSC = proposal.Resolve("rejected", actor, reason)
    If $$$ISERR(tSC) Quit tSC
    ; The free-text reason stays in the proposal; the audit event carries ids only.
    Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ProposalRejected", proposal.DecisionId, "proposal " _ id, 1, proposal.Kind)
    If $$$ISERR(tSC) Quit tSC
    Set data = ..ProposalView(proposal)
    Quit $$$OK
}

ClassMethod ConfirmProposal(id As %Integer, actor As %String, authorization As %String, Output data As %DynamicObject) As %Status
{
    Lock +^MyOwn.Agent.Lock("proposal", id):5
    If '$Test Quit $$$ERROR($$$GeneralError, "PROPOSAL_BUSY")
    Set tSC = $$$OK
    Try {
        Set tSC = ..ConfirmProposalLocked(id, actor, authorization, .data)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Lock -^MyOwn.Agent.Lock("proposal", id)
    Quit tSC
}

ClassMethod ConfirmProposalLocked(id As %Integer, actor As %String, authorization As %String, Output data As %DynamicObject) As %Status [ Private ]
{
    Set proposal = ##class(MyOwn.Agent.Proposal).%OpenId(id)
    If '$IsObject(proposal) Quit $$$ERROR($$$GeneralError, "PROPOSAL_NOT_FOUND")
    If proposal.State '= "pending" Quit $$$ERROR($$$GeneralError, "PROPOSAL_ALREADY_RESOLVED")
    If proposal.IsExpired() {
        Set proposal.State = "expired"
        Set proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
        Set proposal.ResultMessage = "The proposal expired before confirmation."
        Set tSC = proposal.%Save()
        If $$$ISERR(tSC) Quit tSC
        Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ProposalExpired", proposal.DecisionId, "proposal " _ id, 1, "ttl")
        If $$$ISERR(tSC) Quit tSC
        Quit $$$ERROR($$$GeneralError, "PROPOSAL_EXPIRED")
    }

    Set requester = ""
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 1 Requester FROM MyOwn_Agent.AccessRequest WHERE DecisionId = ? ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set requestResult = statement.%Execute(proposal.DecisionId)
    If requestResult.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, requestResult.%Message)
    If requestResult.%Next() Set requester = requestResult.%Get("Requester")
    If (requester '= "") && ($ZConvert(requester, "U") = $ZConvert(actor, "U")) Quit $$$ERROR($$$GeneralError, "SEPARATION_OF_DUTIES")

    Set targetType = proposal.TargetType
    Set targetId = proposal.TargetId
    If targetType = "user-role" {
        Set targetUser = $Piece(proposal.TargetId, "|", 1)
        Set targetId = $Piece(proposal.TargetId, "|", 2)
        Set targetType = "role"
        Set prohibited = ##class(MyOwn.Agent.Policy.Prohibited).Check(proposal.Kind, "user", targetUser, requester, actor, 1, .prohibitedReason)
        If prohibited Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")
    }
    Set prohibited = ##class(MyOwn.Agent.Policy.Prohibited).Check(proposal.Kind, targetType, targetId, requester, actor, 1, .prohibitedReason)
    If prohibited Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")

    Set tSC = ..ReadCurrentTarget(proposal, authorization, .current, .manageable)
    If $$$ISERR(tSC) Quit tSC
    Set currentFingerprint = ..Fingerprint(current.%ToJSON())
    If currentFingerprint '= proposal.Fingerprint {
        Set proposal.State = "expired"
        Set proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
        Set proposal.ResultMessage = "The target changed after the proposal was created."
        Set tSC = proposal.%Save()
        If $$$ISERR(tSC) Quit tSC
        Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ProposalExpired", proposal.DecisionId, "proposal " _ id, 1, "target-changed")
        If $$$ISERR(tSC) Quit tSC
        Quit $$$ERROR($$$GeneralError, "TARGET_CHANGED")
    }
    Set prohibited = ##class(MyOwn.Agent.Policy.Prohibited).Check(proposal.Kind, targetType, targetId, requester, actor, manageable, .prohibitedReason)
    If prohibited Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")

    Set proposal.State = "confirmed"
    Set proposal.ResolvedBy = $Extract(actor, 1, 160)
    Set proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
    Set tSC = proposal.%Save()
    If $$$ISERR(tSC) Quit tSC
    ; No execution happens unless the human confirmation itself was audited.
    Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ProposalConfirmed", proposal.DecisionId, "proposal " _ id, 1, proposal.Kind)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ExecuteProposal(proposal, authorization, .execution)
    If $$$ISERR(tSC) {
        Set proposal.State = "failed"
        Set proposal.ResultMessage = "The confirmed action could not be completed."
        Set saveStatus = proposal.%Save()
        Set auditStatus = ##class(MyOwn.Service.Audit).RecordAgent("ExecutionResult", proposal.DecisionId, "proposal " _ id, 0, "execution-failed")
        Set feedbackStatus = ..PublishExecutionFeedback(proposal, "failed", proposal.ResultMessage)
        Quit tSC
    }
    Set tSC = ..VerifyExecution(proposal, authorization, .readBack)
    If $$$ISERR(tSC) {
        Set proposal.State = "failed"
        Set proposal.ResultMessage = "The action completed, but the expected state could not be verified."
        Set saveStatus = proposal.%Save()
        Set auditStatus = ##class(MyOwn.Service.Audit).RecordAgent("ExecutionResult", proposal.DecisionId, "proposal " _ id, 0, "readback-failed")
        Set feedbackStatus = ..PublishExecutionFeedback(proposal, "failed", proposal.ResultMessage)
        Quit tSC
    }
    Set proposal.State = "executed"
    Set proposal.ResultMessage = execution.%Get("message", "The confirmed action was executed.")
    Set tSC = proposal.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ExecutionResult", proposal.DecisionId, "proposal " _ id, 1, "executed")
    If $$$ISERR(tSC) Quit tSC
    Set feedbackStatus = ..PublishExecutionFeedback(proposal, "executed", proposal.ResultMessage)
    Set data = ..ProposalView(proposal)
    Set data.execution = execution
    Set data.execution.readBack = readBack
    Set data.feedbackRecorded = $$$ISOK(feedbackStatus)
    Quit $$$OK
}

ClassMethod ListAccessRequests(actor As %String, includeAll As %Boolean, Output items As %DynamicArray) As %Status
{
    Set items = []
    Set statement = ##class(%SQL.Statement).%New()
    If includeAll {
        Set tSC = statement.%Prepare("SELECT TOP 100 ID FROM MyOwn_Agent.AccessRequest ORDER BY ID DESC")
        If $$$ISERR(tSC) Quit tSC
        Set result = statement.%Execute()
    } Else {
        Set tSC = statement.%Prepare("SELECT TOP 100 ID FROM MyOwn_Agent.AccessRequest WHERE Requester = ? ORDER BY ID DESC")
        If $$$ISERR(tSC) Quit tSC
        Set result = statement.%Execute(actor)
    }
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set request = ##class(MyOwn.Agent.AccessRequest).%OpenId(result.%Get("ID"))
        If $IsObject(request) Do items.%Push(..AccessRequestView(request))
    }
    Quit $$$OK
}

ClassMethod LedgerSummary(Output data As %DynamicObject) As %Status
{
    Set data = {}
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT COUNT(*) AS Decisions, COALESCE(SUM(TotalTokens),0) AS TotalTokens, COALESCE(SUM(CostEstimateUSD),0) AS CostUSD, COALESCE(AVG(DurationMs),0) AS AverageDurationMs FROM MyOwn_Agent.Ledger")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute()
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    If result.%Next() {
        Set data.decisions = result.%Get("Decisions")
        Set data.totalTokens = result.%Get("TotalTokens")
        Set data.costEstimateUSD = result.%Get("CostUSD")
        Set data.averageDurationMs = result.%Get("AverageDurationMs")
    }
    Quit $$$OK
}

ClassMethod ProductionStatus(Output data As %DynamicObject) As %Status
{
    Set data = {}
    Set tSC = ##class(Ens.Director).GetProductionStatus(.production, .state, 10, 1)
    If $$$ISERR(tSC) Quit tSC
    Set data.name = production
    Set data.state = state
    Set data.running = (production = "MyOwn.Production.Main") && (state = 1)
    Set data.items = []
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT Name, ClassName, Enabled FROM Ens_Config.Item ORDER BY Name")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute()
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set item = {}
        Set item.name = result.%Get("Name")
        Set item.className = result.%Get("ClassName")
        Set item.enabled = result.%Get("Enabled")
        Do data.items.%Push(item)
    }
    Quit $$$OK
}

ClassMethod ControlProduction(action As %String, Output data As %DynamicObject) As %Status
{
    Set action = $ZConvert(action, "L")
    If action = "start" {
        Set tSC = ##class(Ens.Director).StartProduction("MyOwn.Production.Main")
    } ElseIf action = "stop" {
        Set tSC = ##class(Ens.Director).StopProduction(30, 0)
    } Else {
        Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    }
    If $$$ISERR(tSC) Quit tSC
    Quit ..ProductionStatus(.data)
}

ClassMethod Guardrails(Output data As %DynamicObject) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Policy.Prohibited).Rules(.rules)
    If $$$ISERR(tSC) Quit tSC
    Set data = {}
    Set data.prohibitedTargets = rules
    Set data.stateChangesRequireConfirmation = 1
    Set data.agentToolsAreReadOnly = 1
    Set data.modelOutputIsUntrusted = 1
    Set data.separationOfDuties = 1
    Set data.sentToModel = ["sanitized health metrics", "sanitized task metadata", "sanitized log excerpts", "server-calculated privilege delta"]
    Set data.neverSentToModel = ["passwords", "API keys", "authorization headers", "private keys", "raw credential values"]
    Quit $$$OK
}

ClassMethod UpdateConfig(input As %DynamicObject, actor As %String, Output data As %DynamicObject) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit tSC
    If input.%IsDefined("enginePreference") {
        Set value = $ZConvert(input.enginePreference, "L")
        If '##class(MyOwn.Agent.Config).ValidateChoice(value, "auto,rules,aihub") Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.EnginePreference = value
    }
    If input.%IsDefined("provider") Set config.Provider = $Extract(##class(MyOwn.Agent.Sanitize).Identifier(input.provider), 1, 80)
    If input.%IsDefined("model") Set config.Model = $Extract(##class(MyOwn.Agent.Sanitize).Text(input.model, 160), 1, 160)
    If input.%IsDefined("baseURL") Set config.BaseURL = $Extract(##class(MyOwn.Agent.Sanitize).Text(input.baseURL, 500), 1, 500)
    If input.%IsDefined("autonomyTriage") {
        Set value = $ZConvert(input.autonomyTriage, "L")
        If '##class(MyOwn.Agent.Config).ValidateChoice(value, "advise,assist,auto-safe") Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.AutonomyTriage = value
    }
    If input.%IsDefined("autonomyAccess") {
        Set value = $ZConvert(input.autonomyAccess, "L")
        If '##class(MyOwn.Agent.Config).ValidateChoice(value, "advise,assist,auto-safe") Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.AutonomyAccess = value
    }
    If input.%IsDefined("dailyTokenBudget") {
        If (+input.dailyTokenBudget < 0) || (+input.dailyTokenBudget > 100000000) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.DailyTokenBudget = +input.dailyTokenBudget
    }
    If input.%IsDefined("perDecisionTokenBudget") {
        If (+input.perDecisionTokenBudget < 0) || (+input.perDecisionTokenBudget > 1000000) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.PerDecisionTokenBudget = +input.perDecisionTokenBudget
    }
    If input.%IsDefined("cooldownMinutes") {
        If (+input.cooldownMinutes < 0) || (+input.cooldownMinutes > 1440) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.CooldownMinutes = +input.cooldownMinutes
    }
    If input.%IsDefined("maxAgentCallsPerHour") {
        If (+input.maxAgentCallsPerHour < 1) || (+input.maxAgentCallsPerHour > 1000) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.MaxAgentCallsPerHour = +input.maxAgentCallsPerHour
    }
    If input.%IsDefined("proposalTTLMinutes") {
        If (+input.proposalTTLMinutes < 1) || (+input.proposalTTLMinutes > 10080) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
        Set config.ProposalTTLMinutes = +input.proposalTTLMinutes
    }
    If input.%IsDefined("readOnly") Set config.ReadOnly = +input.readOnly
    If input.%IsDefined("demoMode") Set config.DemoMode = +input.demoMode
    Set tSC = config.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ConfigChange", 0, "agent-config", 1, "", 0)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(MyOwn.Agent.Config).PublicView(.data)
}

ClassMethod SetKillSwitch(enabled As %Boolean, actor As %String, Output data As %DynamicObject) As %Status
{
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit tSC
    Set config.KillSwitch = +enabled
    Set tSC = config.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("KillSwitch", 0, "kill-switch", 1, $Select(enabled:"enabled", 1:"disabled"), 0)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(MyOwn.Agent.Config).PublicView(.data)
}

ClassMethod ListLedger(Output items As %DynamicArray) As %Status
{
    Set items = []
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 100 ID FROM MyOwn_Agent.Ledger ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute()
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set ledger = ##class(MyOwn.Agent.Ledger).%OpenId(result.%Get("ID"))
        If $IsObject(ledger) Do items.%Push(..LedgerView(ledger))
    }
    Quit $$$OK
}

ClassMethod Trace(traceId As %String, Output data As %DynamicObject) As %Status
{
    Set traceId = ##class(MyOwn.Agent.Sanitize).Identifier(traceId)
    If traceId = "" Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set data = {}
    Set data.traceId = traceId
    Set data.timeline = []
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT ID, ReceivedAt, Source, Status FROM MyOwn_Agent.Event WHERE TraceId = ? ORDER BY ID")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(traceId)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set item = {}
        Set item.type = "event"
        Set item.id = result.%Get("ID")
        Set item.at = result.%Get("ReceivedAt")
        Set item.source = result.%Get("Source")
        Set item.status = result.%Get("Status")
        Do data.timeline.%Push(item)
    }
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT ID, DecidedAt, Engine, Action, ValidationStatus FROM MyOwn_Agent.Decision WHERE TraceId = ? ORDER BY ID")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(traceId)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set item = {}
        Set item.type = "decision"
        Set item.id = result.%Get("ID")
        Set item.at = result.%Get("DecidedAt")
        Set item.engine = result.%Get("Engine")
        Set item.action = result.%Get("Action")
        Set item.status = result.%Get("ValidationStatus")
        Do data.timeline.%Push(item)
    }
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT ID FROM MyOwn_Agent.Ledger WHERE TraceId = ? ORDER BY ID")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(traceId)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set ledger = ##class(MyOwn.Agent.Ledger).%OpenId(result.%Get("ID"))
        If $IsObject(ledger) {
            Set item = ..LedgerView(ledger)
            Set item.type = "ledger"
            Set item.at = ledger.StartedAt
            Do data.timeline.%Push(item)
        }
    }
    Quit $$$OK
}

ClassMethod ListPricing(Output items As %DynamicArray) As %Status
{
    Set items = []
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 100 ID FROM MyOwn_Agent.Pricing ORDER BY Model")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute()
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        Set pricing = ##class(MyOwn.Agent.Pricing).%OpenId(result.%Get("ID"))
        If $IsObject(pricing) {
            Set item = {}
            Set item.id = pricing.%Id()
            Set item.model = pricing.Model
            Set item.inputPer1MTokensUSD = pricing.InputPer1MTokensUSD
            Set item.outputPer1MTokensUSD = pricing.OutputPer1MTokensUSD
            Set item.updatedAt = pricing.UpdatedAt
            Do items.%Push(item)
        }
    }
    Quit $$$OK
}

ClassMethod SavePricing(input As %DynamicObject, actor As %String, Output data As %DynamicObject) As %Status
{
    Set model = $Extract(##class(MyOwn.Agent.Sanitize).Text(input.%Get("model"), 160), 1, 160)
    Set inputPrice = +input.%Get("inputPer1MTokensUSD")
    Set outputPrice = +input.%Get("outputPer1MTokensUSD")
    If (model = "") || (inputPrice < 0) || (outputPrice < 0) Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 1 ID FROM MyOwn_Agent.Pricing WHERE Model = ?")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(model)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    If result.%Next() {
        Set pricing = ##class(MyOwn.Agent.Pricing).%OpenId(result.%Get("ID"))
    } Else {
        Set pricing = ##class(MyOwn.Agent.Pricing).%New()
        Set pricing.Model = model
    }
    Set pricing.InputPer1MTokensUSD = inputPrice
    Set pricing.OutputPer1MTokensUSD = outputPrice
    Set pricing.UpdatedAt = $ZDateTime($Horolog, 3, 1)
    Set tSC = pricing.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ConfigChange", 0, "pricing", 1, model, 0)
    If $$$ISERR(tSC) Quit tSC
    Set data = {}
    Set data.id = pricing.%Id()
    Set data.model = pricing.Model
    Set data.inputPer1MTokensUSD = pricing.InputPer1MTokensUSD
    Set data.outputPer1MTokensUSD = pricing.OutputPer1MTokensUSD
    Set data.updatedAt = pricing.UpdatedAt
    Quit $$$OK
}

ClassMethod LedgerView(ledger As MyOwn.Agent.Ledger) As %DynamicObject [ Private ]
{
    Set data = {}
    Set data.id = ledger.%Id()
    Set data.traceId = ledger.TraceId
    Set data.workflow = ledger.Workflow
    Set data.engine = ledger.Engine
    Set data.provider = ledger.Provider
    Set data.model = ledger.Model
    Set data.startedAt = ledger.StartedAt
    Set data.durationMs = ledger.DurationMs
    Set data.promptTokens = ledger.PromptTokens
    Set data.completionTokens = ledger.CompletionTokens
    Set data.totalTokens = ledger.TotalTokens
    Set data.toolCallCount = ledger.ToolCallCount
    Set data.iterations = ledger.Iterations
    Set data.costEstimateUSD = ledger.CostEstimateUSD
    Set data.outcome = ledger.Outcome
    Quit data
}

/// Public and side-effect free so the adversarial corpus can check it. Text is sanitized
/// again on read, which also covers rows written before evidence was sanitized on save.
ClassMethod DecisionView(decision As MyOwn.Agent.Decision, detail As %Boolean) As %DynamicObject
{
    Set data = {}
    Set data.id = decision.%Id()
    Set data.eventId = decision.EventId
    Set data.workflow = decision.Workflow
    Set data.engine = decision.Engine
    Set data.action = decision.Action
    Set data.severity = decision.Severity
    Set data.riskLevel = decision.RiskLevel
    Set data.targetType = decision.TargetType
    Set data.targetId = decision.TargetId
    Set data.confidence = decision.Confidence
    Set data.validationStatus = decision.ValidationStatus
    Set data.downgradedBy = decision.DowngradedBy
    Set data.traceId = decision.TraceId
    Set data.decidedAt = decision.DecidedAt
    Set gate = ..JSONValue(decision.GateJSON)
    Set proposal = ..ProposalForDecision(decision.%Id())
    Set reused = 0
    ; A decision deduplicated against a pending proposal points to that proposal.
    If '$IsObject(proposal), decision.DowngradedBy = "duplicate-proposal", +gate.%Get("duplicateOf") {
        Set proposal = ##class(MyOwn.Agent.Proposal).%OpenId(+gate.duplicateOf)
        Set reused = $IsObject(proposal)
    }
    Set data.proposalId = $Select($IsObject(proposal):proposal.%Id(), 1:"")
    If detail {
        Set data.conditions = ..PublicDecision({"conditions":(..JSONArray(decision.ConditionsJSON))}).conditions
        Set data.gate = {}
        Set data.gate.finalAction = decision.Action
        Set data.gate.downgradedBy = decision.DowngradedBy
        If gate.%IsDefined("allowed") Set data.gate.allowed = +gate.allowed
        If gate.%IsDefined("createProposal") Set data.gate.createProposal = +gate.createProposal
        If gate.%Get("reason") '= "" Set data.gate.reason = ##class(MyOwn.Agent.Sanitize).Text(gate.reason, 200)
        If +gate.%Get("duplicateOf") Set data.gate.duplicateOf = +gate.duplicateOf
        If $IsObject(proposal) {
            Set data.proposal = {}
            Set data.proposal.id = proposal.%Id()
            Set data.proposal.kind = proposal.Kind
            Set data.proposal.state = proposal.State
            If reused Set data.proposal.reused = 1
        }
        Set data.rationale = ##class(MyOwn.Agent.Sanitize).Text(decision.Rationale, 600)
        Set evidenceJSON = ..ReadStream(decision.EvidenceJSON)
        Set data.evidence = []
        If evidenceJSON '= "" {
            Try {
                Set stored = [].%FromJSON(evidenceJSON)
                If stored.%IsA("%DynamicArray") Set data.evidence = ..SanitizeEvidence(stored)
            } Catch exception {
                Set data.evidence = []
            }
        }
    }
    Quit data
}

ClassMethod ProposalView(proposal As MyOwn.Agent.Proposal) As %DynamicObject [ Private ]
{
    Set data = {}
    Set data.id = proposal.%Id()
    Set data.decisionId = proposal.DecisionId
    Set data.kind = proposal.Kind
    Set data.targetType = proposal.TargetType
    Set data.targetId = proposal.TargetId
    Set data.before = ..JSONValue(..ReadStream(proposal.BeforeJSON))
    Set data.after = ..JSONValue(..ReadStream(proposal.AfterJSON))
    Set data.requiredPrivilege = proposal.RequiredPrivilege
    Set data.undoHint = proposal.UndoHint
    Set data.state = proposal.State
    Set data.createdAt = proposal.CreatedAt
    Set data.expiresAt = proposal.ExpiresAt
    Set data.resolvedBy = proposal.ResolvedBy
    Set data.resolvedAt = proposal.ResolvedAt
    Set data.resultMessage = proposal.ResultMessage
    Quit data
}

/// Public and side-effect free so the adversarial corpus can check it. Messages written
/// before the decision was sanitized at the source are cleaned here as well.
ClassMethod ResponseFromMessage(message As MyOwn.Production.Msg.AgentResponse) As %DynamicObject
{
    Set data = {}
    Set data.traceId = message.TraceId
    Set data.eventId = message.EventId
    Set data.decisionId = message.DecisionId
    Set data.proposalId = message.ProposalId
    Set data.engine = message.Engine
    Set data.outcome = message.Outcome
    Set data.decision = ..PublicDecision(..JSONValue(message.DecisionJSON))
    If message.GateJSON '= "" Set data.gate = ..JSONValue(message.GateJSON)
    If message.Outcome = "suppressed" Set data.status = "suppressed"
    Set data.integrationSource = "interoperability"
    Quit data
}

ClassMethod ReadCurrentTarget(proposal As MyOwn.Agent.Proposal, authorization As %String, Output current As %DynamicObject, Output manageable As %Boolean) As %Status [ Private ]
{
    Set manageable = 1
    If proposal.TargetType = "task" {
        Set tSC = ##class(MyOwn.Service.Tasks).GetTask(+proposal.TargetId, authorization, .task, .source)
        If $$$ISERR(tSC) Quit tSC
        Set manageable = task.%Get("manageable")
        Set current = ..TaskState(task)
        Quit $$$OK
    }
    If proposal.TargetType = "user-role" {
        Set user = $Piece(proposal.TargetId, "|", 1)
        Set tSC = ##class(MyOwn.Service.Permissions).GetUserDetail(user, authorization, .profile, .source)
        If $$$ISERR(tSC) Quit tSC
        Set current = {}
        Set current.user = user
        Set current.roles = profile.effectiveRoles
        Quit $$$OK
    }
    Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")
}

ClassMethod ExecuteProposal(proposal As MyOwn.Agent.Proposal, authorization As %String, Output result As %DynamicObject) As %Status [ Private ]
{
    If $Extract(proposal.Kind, 1, 5) = "task." {
        Set action = $Piece(proposal.Kind, ".", 2)
        Set tSC = ##class(MyOwn.Service.Tasks).PerformAction(+proposal.TargetId, action, authorization, .result, .source)
        If $$$ISERR(tSC) Quit tSC
        Set result.integrationSource = source
        Quit $$$OK
    }
    If proposal.Kind = "role.assign" {
        Set user = $Piece(proposal.TargetId, "|", 1)
        Set role = $Piece(proposal.TargetId, "|", 2)
        Set tSC = ##class(MyOwn.Service.Permissions).AddUserRole(user, role, authorization, .result, .source)
        If $$$ISERR(tSC) Quit tSC
        Set result.integrationSource = source
        Set result.message = "The role was assigned successfully."
        Quit $$$OK
    }
    Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")
}

ClassMethod VerifyExecution(proposal As MyOwn.Agent.Proposal, authorization As %String, Output current As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..ReadCurrentTarget(proposal, authorization, .current, .manageable)
    If $$$ISERR(tSC) Quit tSC
    Set expected = ..JSONValue(..ReadStream(proposal.AfterJSON))
    If proposal.TargetType = "task" {
        If current.%Get("suspended") '= expected.%Get("suspended") Quit $$$ERROR($$$GeneralError, "EXECUTION_READBACK_FAILED")
        Quit $$$OK
    }
    If proposal.TargetType = "user-role" {
        Set role = $Piece(proposal.TargetId, "|", 2)
        If '..ArrayContains(current.%Get("roles"), role) Quit $$$ERROR($$$GeneralError, "EXECUTION_READBACK_FAILED")
        Quit $$$OK
    }
    Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")
}

ClassMethod ArrayContains(items As %DynamicArray, value As %String) As %Boolean [ Private ]
{
    If '$IsObject(items) Quit 0
    Set found = 0
    For index = 0:1:(items.%Size() - 1) {
        If $ZConvert(items.%Get(index), "U") = $ZConvert(value, "U") Set found = 1
    }
    Quit found
}

ClassMethod PublishExecutionFeedback(proposal As MyOwn.Agent.Proposal, state As %String, message As %String) As %Status [ Private ]
{
    Set traceId = ""
    Set decision = ##class(MyOwn.Agent.Decision).%OpenId(proposal.DecisionId)
    If $IsObject(decision) Set traceId = decision.TraceId
    Set feedback = ##class(MyOwn.Production.Msg.ExecutionFeedback).%New()
    Set feedback.ProposalId = proposal.%Id()
    Set feedback.State = state
    Set feedback.Message = ##class(MyOwn.Agent.Sanitize).Text(message, 500)
    Set feedback.TraceId = traceId
    Set tSC = ##class(Ens.Director).CreateBusinessService("ExecutionFeedbackService", .service)
    If $$$ISERR(tSC) Quit tSC
    Quit service.ProcessInput(feedback, .response)
}

ClassMethod TaskState(task As %DynamicObject) As %DynamicObject [ Private ]
{
    Set state = {}
    If '$IsObject(task) Quit state
    Set state.id = +task.%Get("id")
    Set state.name = task.%Get("name")
    Set state.namespace = $ZConvert(task.%Get("namespace"), "U")
    Set state.suspended = +task.%Get("suspended")
    Set state.manageable = +task.%Get("manageable")
    Quit state
}

ClassMethod ReadStream(stream As %Stream.Object) As %String [ Private ]
{
    If '$IsObject(stream) Quit ""
    Do stream.Rewind()
    Set value = ""
    While 'stream.AtEnd {
        Set value = value _ stream.Read(32000)
    }
    Quit value
}

ClassMethod JSONArray(value As %String) As %DynamicArray [ Private ]
{
    Set parsed = ..JSONValue(value)
    Quit $Select(parsed.%IsA("%DynamicArray"):parsed, 1:[])
}

ClassMethod ProposalForDecision(decisionId As %Integer) As MyOwn.Agent.Proposal [ Private ]
{
    If 'decisionId Quit ""
    Set statement = ##class(%SQL.Statement).%New()
    If $$$ISERR(statement.%Prepare("SELECT TOP 1 ID FROM MyOwn_Agent.Proposal WHERE DecisionId = ? ORDER BY ID DESC")) Quit ""
    Set result = statement.%Execute(decisionId)
    If (result.%SQLCODE < 0) || 'result.%Next() Quit ""
    Quit ##class(MyOwn.Agent.Proposal).%OpenId(result.%Get("ID"))
}

ClassMethod JSONValue(value As %String) As %DynamicAbstractObject [ Private ]
{
    If value = "" Quit {}
    Set parsed = {}
    Try {
        Set parsed = {}.%FromJSON(value)
    } Catch exception {
        Set parsed = {}
    }
    Quit parsed
}

}
