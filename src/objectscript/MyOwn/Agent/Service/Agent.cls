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

ClassMethod Analyze(workflow As %String, contextJSON As %String, source As %String = "manual", traceId As %String = "", actor As %String = "", Output response As %DynamicObject) As %Status
{
    Set response = {}
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
        Set response.traceId = traceId
        Set response.eventId = eventId
        Set response.status = "suppressed"
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
    Set tSC = ##class(MyOwn.Agent.Policy.Gate).Evaluate(decision, context, config, actor, .gate)
    If $$$ISERR(tSC) Quit tSC
    Set decision.action = gate.finalAction
    Set tSC = ..SaveDecision(eventId, workflow, engine, decision, validationStatus, gate.downgradedBy, config, traceId, .decisionId)
    If $$$ISERR(tSC) Quit tSC

    Set proposalId = ""
    If gate.allowed, gate.createProposal {
        Set tSC = ..CreateProposal(decisionId, decision, context, config, .proposalId)
        If $$$ISERR(tSC) Quit tSC
    }
    Set duration = ($Piece($Horolog, ",", 2) - startSeconds) * 1000
    If duration < 0 Set duration = duration + 86400000
    Set tSC = ..SaveLedger(traceId, workflow, engine, engineResult, started, duration, outcome, .ledgerId)
    If $$$ISERR(tSC) Quit tSC
    Set response.traceId = traceId
    Set response.eventId = eventId
    Set response.decisionId = decisionId
    Set response.proposalId = proposalId
    Set response.engine = engine
    Set response.outcome = outcome
    Set response.decision = decision
    Set response.gate = gate
    Quit $$$OK
}

ClassMethod SubmitAccessRequest(role As %String, justification As %String, authorization As %String, requester As %String, Output response As %DynamicObject) As %Status
{
    Set role = ##class(MyOwn.Agent.Sanitize).Identifier(role)
    Set justification = ##class(MyOwn.Agent.Sanitize).Text(justification, 500)
    If (role = "") || (justification = "") Quit $$$ERROR($$$GeneralError, "INVALID_REQUEST")
    Set request = ##class(MyOwn.Agent.AccessRequest).%New()
    Set request.Requester = requester
    Set request.RoleRequested = role
    Set request.Justification = justification
    Set request.Status = "new"
    Set request.CreatedAt = $ZDateTime($Horolog, 3, 1)
    Set tSC = request.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set requestId = request.%Id()
    Set tSC = ##class(MyOwn.Agent.Context.Access).ComparePrivileges(requester, role, authorization, .context)
    If $$$ISERR(tSC) Quit tSC
    Set context.requestId = requestId
    Set context.untrustedData.justification = justification
    Set accessEvent = ##class(MyOwn.Production.Msg.AccessRequestEvent).%New()
    Set accessEvent.RequestId = requestId
    Set accessEvent.Requester = requester
    Set accessEvent.RoleRequested = role
    Set accessEvent.ContextJSON = context.%ToJSON()
    Set accessEvent.TraceId = $System.Util.CreateGUID()
    Set tSC = ##class(Ens.Director).CreateBusinessService("AccessRequestService", .service)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = service.ProcessInput(accessEvent, .agentResponse)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(agentResponse) Quit $$$ERROR($$$GeneralError, "AGENT_RESPONSE_MISSING")
    Set request.DecisionId = agentResponse.DecisionId
    Set request.Status = "decided"
    Set tSC = request.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set response = ..ResponseFromMessage(agentResponse)
    Set response.requestId = requestId
    Quit $$$OK
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

ClassMethod SaveDecision(eventId As %Integer, workflow As %String, engine As %String, value As %DynamicObject, validationStatus As %String, downgradedBy As %String, config As MyOwn.Agent.Config, traceId As %String, Output id As %Integer) As %Status [ Private ]
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
    Set decision.ValidationStatus = validationStatus
    Set decision.DowngradedBy = downgradedBy
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

ClassMethod CreateProposal(decisionId As %Integer, decision As %DynamicObject, context As %DynamicObject, config As MyOwn.Agent.Config, Output id As %Integer) As %Status [ Private ]
{
    Set proposal = ##class(MyOwn.Agent.Proposal).%New()
    Set proposal.DecisionId = decisionId
    If decision.%Get("workflow") = "access-request" {
        Set proposal.Kind = "role.assign"
        Set proposal.TargetType = "user-role"
        Set proposal.TargetId = decision.%Get("user") _ "|" _ decision.%Get("role")
        Set before = {}
        Set before.user = decision.%Get("user")
        Set before.roles = context.%Get("currentRoles")
        Set after = {}
        Set after.user = decision.%Get("user")
        Set after.roleToAssign = decision.%Get("role")
        Set proposal.RequiredPrivilege = "%Admin_Secure"
        Set proposal.UndoHint = "Remove the assigned role from the user in Permissions."
    } Else {
        Set proposal.Kind = $Replace(decision.%Get("action"), "propose_", "")
        Set proposal.Kind = $Replace(proposal.Kind, "task_", "task.")
        Set proposal.TargetType = "task"
        Set proposal.TargetId = decision.%Get("targetId")
        Set before = ..TaskState(context.%Get("task"))
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
ClassMethod StableKey(workflow As %String, context As %DynamicObject) As %String [ Private ]
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
    If $IsObject(task) Set key = key _ "|t:" _ task.%Get("id") _ ":" _ (+task.%Get("suspended")) _ ":" _ (+task.%Get("consecutiveFailures"))
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
    Set tSC = ##class(MyOwn.Service.Audit).Record("AgentProposalReject", id, 1)
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
        Quit $$$ERROR($$$GeneralError, "TARGET_CHANGED")
    }
    Set prohibited = ##class(MyOwn.Agent.Policy.Prohibited).Check(proposal.Kind, targetType, targetId, requester, actor, manageable, .prohibitedReason)
    If prohibited Quit $$$ERROR($$$GeneralError, "PROHIBITED_TARGET")

    Set proposal.State = "confirmed"
    Set proposal.ResolvedBy = $Extract(actor, 1, 160)
    Set proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
    Set tSC = proposal.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ExecuteProposal(proposal, authorization, .execution)
    If $$$ISERR(tSC) {
        Set proposal.State = "failed"
        Set proposal.ResultMessage = "The confirmed action could not be completed."
        Set saveStatus = proposal.%Save()
        Set auditStatus = ##class(MyOwn.Service.Audit).Record("AgentProposalConfirm", id, 0)
        Set feedbackStatus = ..PublishExecutionFeedback(proposal, "failed", proposal.ResultMessage)
        Quit tSC
    }
    Set tSC = ..VerifyExecution(proposal, authorization, .readBack)
    If $$$ISERR(tSC) {
        Set proposal.State = "failed"
        Set proposal.ResultMessage = "The action completed, but the expected state could not be verified."
        Set saveStatus = proposal.%Save()
        Set auditStatus = ##class(MyOwn.Service.Audit).Record("AgentProposalConfirm", id, 0)
        Set feedbackStatus = ..PublishExecutionFeedback(proposal, "failed", proposal.ResultMessage)
        Quit tSC
    }
    Set proposal.State = "executed"
    Set proposal.ResultMessage = execution.%Get("message", "The confirmed action was executed.")
    Set tSC = proposal.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(MyOwn.Service.Audit).Record("AgentProposalConfirm", id, 1)
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
        If $IsObject(request) {
            Set item = {}
            Set item.id = request.%Id()
            Set item.requester = request.Requester
            Set item.roleRequested = request.RoleRequested
            Set item.justification = request.Justification
            Set item.status = request.Status
            Set item.decisionId = request.DecisionId
            Set item.createdAt = request.CreatedAt
            Do items.%Push(item)
        }
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
    Set tSC = ##class(MyOwn.Service.Audit).Record("AgentConfigChange", actor, 1)
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
    Set tSC = ##class(MyOwn.Service.Audit).Record("AgentKillSwitch", $Select(enabled:"enabled", 1:"disabled") _ " by " _ actor, 1)
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
    Set tSC = ##class(MyOwn.Service.Audit).Record("AgentPricingChange", model _ " by " _ actor, 1)
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

ClassMethod DecisionView(decision As MyOwn.Agent.Decision, detail As %Boolean) As %DynamicObject [ Private ]
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
    If detail {
        Set data.rationale = decision.Rationale
        Set evidenceJSON = ..ReadStream(decision.EvidenceJSON)
        If evidenceJSON '= "" {
            Try {
                Set data.evidence = [].%FromJSON(evidenceJSON)
            } Catch exception {
                Set data.evidence = []
            }
        } Else {
            Set data.evidence = []
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

ClassMethod ResponseFromMessage(message As MyOwn.Production.Msg.AgentResponse) As %DynamicObject [ Private ]
{
    Set data = {}
    Set data.traceId = message.TraceId
    Set data.eventId = message.EventId
    Set data.decisionId = message.DecisionId
    Set data.proposalId = message.ProposalId
    Set data.engine = message.Engine
    Set data.outcome = message.Outcome
    Set data.decision = ..JSONValue(message.DecisionJSON)
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
    Set state.namespace = task.%Get("namespace")
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
