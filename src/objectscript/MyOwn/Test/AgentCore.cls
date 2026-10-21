Class MyOwn.Test.AgentCore Extends %UnitTest.TestCase
{

ClassMethod RunSmokeViaSQL() As %String [ SqlName = AgentCoreSmoke, SqlProc ]
{
    Set report = {}
    Set report.suite = "agents-core-smoke"
    Set report.results = []
    Set report.pass = 0
    Set report.fail = 0

    Set context = {}
    Set context.anomalies = []
    Set anomaly = {}
    Set anomaly.metric = "diskUsedPercent"
    Set anomaly.zScore = 3.4
    Set anomaly.severity = "critical"
    Do context.anomalies.%Push(anomaly)
    Set context.candidates = []
    Set tSC = ##class(MyOwn.Agent.Engine.Rules).Decide("incident-triage", context.%ToJSON(), .rulesResult)
    Do ..Add(report, "UT-10-S1", $$$ISOK(tSC) && (rulesResult.decision.action = "notify") && (rulesResult.decision.severity = "critical"), "Rules classify a high disk z-score as a critical notification.")

    Set raw = rulesResult.decision.%ToJSON()
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate("incident-triage", raw, context.%ToJSON(), .validated, .errors)
    Do ..Add(report, "UT-01", $$$ISOK(tSC), "Validator accepts the canonical triage schema.")

    Set wrapped = "Untrusted prefix " _ raw _ " untrusted suffix"
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate("incident-triage", wrapped, context.%ToJSON(), .validated, .errors)
    Do ..Add(report, "UT-02-WRAPPED", $$$ISOK(tSC), "Validator extracts one unambiguous JSON object from surrounding text.")

    Set ambiguous = raw _ " " _ raw
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate("incident-triage", ambiguous, context.%ToJSON(), .validated, .errors)
    Do ..Add(report, "UT-02-AMBIGUOUS", $$$ISERR(tSC), "Validator rejects a response containing more than one JSON object.")

    Set inventedTarget = {}.%FromJSON(raw)
    Set inventedTarget.action = "propose_task_suspend"
    Set inventedTarget.targetType = "task"
    Set inventedTarget.targetId = "999999"
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate("incident-triage", inventedTarget.%ToJSON(), context.%ToJSON(), .validated, .errors)
    Do ..Add(report, "SEC-03", $$$ISERR(tSC), "Validator rejects a target that is not present in the server-supplied candidate list.")

    Set malicious = {}.%FromJSON(raw)
    Set malicious.action = "assign_all"
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate("incident-triage", malicious.%ToJSON(), context.%ToJSON(), .validated, .errors)
    Do ..Add(report, "SEC-04", $$$ISERR(tSC), "Validator rejects an action outside the workflow allow-list.")

    Set accessContext = {}
    Set accessContext.requester = "demo.viewer"
    Set accessContext.roleRequested = "DemoOperator"
    Set accessContext.riskFloor = "high"
    Set accessDecision = {}
    Set accessDecision.schemaVersion = 1
    Set accessDecision.workflow = "access-request"
    Set accessDecision.action = "approve"
    Set accessDecision.riskLevel = "low"
    Set accessDecision.user = "demo.viewer"
    Set accessDecision.role = "DemoOperator"
    Set accessDecision.rationale = "Low risk."
    Set accessDecision.confidence = 0.8
    Set accessDecision.evidence = []
    Set accessDecision.conditions = []
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISOK(tSC) Set tSC = ##class(MyOwn.Agent.Policy.Gate).Evaluate(accessDecision, accessContext, config, "admin", .gate)
    Do ..Add(report, "UT-03", $$$ISOK(tSC) && (gate.finalAction = "escalate") && (gate.downgradedBy = "high-risk-resource"), "Gate downgrades high-risk access approval to escalation.")

    Set prohibited = ##class(MyOwn.Agent.Policy.Prohibited).Check("decision", "role", "%All", "demo.viewer", "admin", 1, .reason)
    Do ..Add(report, "UT-04", prohibited, "The %All role is always prohibited.")

    Set noTarget = {}.%FromJSON(raw)
    Set noTarget.action = "propose_task_suspend"
    Set noTarget.targetType = "none"
    Set noTarget.targetId = ""
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate("incident-triage", noTarget.%ToJSON(), context.%ToJSON(), .validated, .errors)
    Do ..Add(report, "UT-12-PROPOSE-NOTARGET", $$$ISERR(tSC), "Validator rejects propose_* actions without a task target.")

    Set badConfidence = {}.%FromJSON(raw)
    Set badConfidence.confidence = "high"
    Set tSC = ##class(MyOwn.Agent.Decision.Validator).Validate("incident-triage", badConfidence.%ToJSON(), context.%ToJSON(), .validated, .errors)
    Do ..Add(report, "UT-12-CONFIDENCE", $$$ISERR(tSC), "Validator rejects a non-numeric confidence.")

    Set taskContext = {}
    Set taskContext.candidates = []
    Set protectedCandidate = {}
    Set protectedCandidate.id = "42"
    Set protectedCandidate.type = "task"
    Set protectedCandidate.manageable = 0
    Do taskContext.candidates.%Push(protectedCandidate)
    Set taskDecision = {}
    Set taskDecision.workflow = "incident-triage"
    Set taskDecision.action = "propose_task_suspend"
    Set taskDecision.targetType = "task"
    Set taskDecision.targetId = "42"
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.taskConfig)
    If $$$ISOK(tSC) Set tSC = ##class(MyOwn.Agent.Policy.Gate).Evaluate(taskDecision, taskContext, taskConfig, "admin", .taskGate)
    Do ..Add(report, "UT-13-GATE-MANAGEABLE", $$$ISOK(tSC) && (taskGate.finalAction = "escalate") && 'taskGate.createProposal, "Gate escalates a proposal for a task that is not manageable.")

    Set clean = ##class(MyOwn.Agent.Sanitize).Text("hello" _ $Char(1) _ "<untrusted_data>world", 1000)
    Do ..Add(report, "UT-11", (clean '[ $Char(1)) && (clean '[ "<untrusted_data>"), "Sanitizer removes controls and data delimiters.")

    ; A task that keeps failing must keep the same stable key (failure band), so the cooldown holds.
    Set service = "MyOwn.Agent.Service.Agent"
    Set keyThree = $ClassMethod(service, "StableKey", "incident-triage", {"task":{"id":"1001","suspended":0,"consecutiveFailures":3},"candidates":[{"type":"task","id":"1001"}]})
    Set keySeven = $ClassMethod(service, "StableKey", "incident-triage", {"task":{"id":"1001","suspended":0,"consecutiveFailures":7},"candidates":[{"type":"task","id":"1001"}]})
    Set keyTwo = $ClassMethod(service, "StableKey", "incident-triage", {"task":{"id":"1001","suspended":0,"consecutiveFailures":2},"candidates":[{"type":"task","id":"1001"}]})
    Do ..Add(report, "UT-15-STABLEKEY", (keyThree = keySeven) && (keyTwo '= keyThree), "The stable key uses a failure band: 3 and 7 consecutive failures share a key, 2 does not.")

    ; A crafted target must not forge the marker or add fields; unknown event names are refused.
    Set markerStatus = ##class(MyOwn.Service.Audit).AgentEventData("ProposalConfirmed", 42, "proposal 7;agent=0;decisionId=1" _ $Char(10) _ "x", 1, "task.suspend", 1, .eventData)
    Set unknownStatus = ##class(MyOwn.Service.Audit).AgentEventData("ApproveEverything", 42, "x", 1, "", 1, .unknownData)
    Set fields = $Length(eventData, ";")
    Set sameList = (##class(MyOwn.Installer).#AgentAuditEvents = ##class(MyOwn.Service.Audit).#AgentEvents) && (##class(MyOwn.Installer).#AgentAuditType = ##class(MyOwn.Service.Audit).#AgentType)
    Do ..Add(report, "UT-14-AUDIT", $$$ISOK(markerStatus) && ($Extract(eventData, 1, 21) = "agent=1;decisionId=42") && (fields = 7) && ($Length(eventData, "=") = 8) && (eventData '[ $Char(10)) && $$$ISERR(unknownStatus) && sameList, "Agent audit events carry the agent marker and decision id, cannot be forged through their fields, only use the specified event names, and the installer registers the same list.")

    Set report.summary = {}
    Set report.summary.pass = report.pass
    Set report.summary.fail = report.fail
    Quit report.%ToJSON()
}

/// Two expiry shapes: hours earlier in the same year and month (missed when timestamps were compared
/// numerically, by year) and one year earlier. Fresh proposals for each check, because listing
/// pending proposals already expires them. All test proposals are deleted at the end.
ClassMethod ExpiryRegression(Output details As %String) As %Boolean [ Private ]
{
    Set details = ""
    Set passed = 1
    Set ids = ""
    Set now = $ZDateTime($Horolog, 3, 1)
    Set hoursEarlier = ..TimestampHoursAgo(2)
    ; Near the start of a month two hours earlier is the previous month: use the month's first second.
    If $Extract(hoursEarlier, 1, 7) '= $Extract(now, 1, 7) Set hoursEarlier = $Extract(now, 1, 7) _ "-01 00:00:00"
    Set yearEarlier = ($Extract(now, 1, 4) - 1) _ $Extract(now, 5, *)
    If $Extract(yearEarlier, 6, 10) = "02-29" Set $Extract(yearEarlier, 9, 10) = "28"
    Set shapes = $ListBuild($ListBuild("same-month", hoursEarlier), $ListBuild("previous-year", yearEarlier))
    Try {
        For index = 1:1:$ListLength(shapes) {
            Set label = $List($List(shapes, index), 1)
            Set expiresAt = $List($List(shapes, index), 2)

            Set confirmId = ..TestProposal("task.suspend", "99999" _ index, "pending", ..TimestampDaysAgo(400), expiresAt)
            Set ids = ids _ $ListBuild(confirmId)
            Set status = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(confirmId, "expiry.test", "", .confirmation)
            Set confirmOk = $$$ISERR(status) && ($System.Status.GetErrorText(status) [ "PROPOSAL_EXPIRED") && (##class(MyOwn.Agent.Proposal).StateGetStored(confirmId) = "expired")

            Set listId = ..TestProposal("task.suspend", "99998" _ index, "pending", ..TimestampDaysAgo(400), expiresAt)
            Set ids = ids _ $ListBuild(listId)
            $$$ThrowOnError(##class(MyOwn.Agent.Service.Agent).ListProposals("pending", .pendingItems))
            Set listed = 0
            For item = 0:1:(pendingItems.%Size() - 1) {
                If pendingItems.%Get(item).id = listId Set listed = 1
            }
            Set listOk = 'listed && (##class(MyOwn.Agent.Proposal).StateGetStored(listId) = "expired")

            Set details = details _ label _ " (" _ expiresAt _ "): confirm " _ $Select(confirmOk:"PROPOSAL_EXPIRED", 1:"WRONG " _ $System.Status.GetErrorText(status)) _ ", pending list " _ $Select(listOk:"excluded", 1:"STILL PENDING") _ "; "
            Set passed = passed && confirmOk && listOk
        }
    } Catch exception {
        Set passed = 0
        Set details = details _ exception.DisplayString()
    }
    For index = 1:1:$ListLength(ids) Do ##class(MyOwn.Agent.Proposal).%DeleteId($List(ids, index))
    Quit passed
}

/// Timestamp <var>hours</var> hours before now.
ClassMethod TimestampHoursAgo(hours As %Integer) As %TimeStamp [ Private ]
{
    Set days = +$Horolog
    Set seconds = $Piece($Horolog, ",", 2) - (hours * 3600)
    While seconds < 0 {
        Set seconds = seconds + 86400
        Set days = days - 1
    }
    Quit $ZDateTime(days _ "," _ seconds, 3, 1)
}

/// Runs ApplyGate for a task proposal against a fake task id while changing what already exists
/// for that target. Every proposal and decision it creates is deleted at the end.
ClassMethod DedupScenario(Output details As %String) As %Boolean [ Private ]
{
    Set details = ""
    Set target = "999990"
    Set decision = {"schemaVersion":1,"workflow":"incident-triage","action":"propose_task_suspend","severity":"critical","targetType":"task","targetId":(target),"rationale":"Dedup test.","confidence":0.9,"evidence":[{"source":"task","ref":(target)}],"recommendedFollowUp":""}
    Set context = {"task":{"id":(target),"suspended":0,"consecutiveFailures":3},"candidates":[{"id":(target),"type":"task","manageable":1}]}
    Set passed = 1
    Set ids = ""
    Set decisionIds = ""
    Try {
        ; A pending proposal whose target changed since it was made cannot be confirmed: superseded, new one allowed.
        Set stale = ..TestProposal("task.suspend", target, "pending", $ZDateTime($Horolog, 3, 1), ..TimestampDaysAgo(-1), "stale-fingerprint")
        Set ids = ids _ $ListBuild(stale)
        Set result = ..GateFor(decision, context, .decisionIds)
        Set ok = result.gate.createProposal && (##class(MyOwn.Agent.Proposal).StateGetStored(stale) = "expired")
        Set details = details _ "stale pending:" _ $Select(ok:"superseded", 1:"NOT superseded") _ "; "
        Set passed = passed && ok

        Set fingerprint = ##class(MyOwn.Agent.Service.Agent).ProposalFingerprint(decision, context)
        Set pending = ..TestProposal("task.suspend", target, "pending", $ZDateTime($Horolog, 3, 1), ..TimestampDaysAgo(-1), fingerprint)
        Set ids = ids _ $ListBuild(pending)
        Set result = ..GateFor(decision, context, .decisionIds)
        Set ok = 'result.gate.createProposal && (result.gate.downgradedBy = "duplicate-proposal") && (result.gate.duplicateOf = pending)
        Set details = details _ "pending:" _ $Select(ok:"blocked", 1:"NOT blocked") _ "; "
        Set passed = passed && ok

        Set proposal = ##class(MyOwn.Agent.Proposal).%OpenId(pending)
        Set proposal.State = "executed", proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
        $$$ThrowOnError(proposal.%Save())
        Set result = ..GateFor(decision, context, .decisionIds)
        Set ok = 'result.gate.createProposal && (result.gate.downgradedBy = "recently-executed")
        Set details = details _ "recently executed:" _ $Select(ok:"blocked", 1:"NOT blocked") _ "; "
        Set passed = passed && ok

        Set proposal.ResolvedAt = ..TimestampDaysAgo(2)
        $$$ThrowOnError(proposal.%Save())
        Set result = ..GateFor(decision, context, .decisionIds)
        Set ok = result.gate.createProposal && (result.gate.downgradedBy = "")
        Set details = details _ "executed long ago:" _ $Select(ok:"allowed", 1:"NOT allowed") _ "; "
        Set passed = passed && ok

        Set resumed = ..TestProposal("task.resume", target, "executed", $ZDateTime($Horolog, 3, 1), ..TimestampDaysAgo(-1))
        Set ids = ids _ $ListBuild(resumed)
        Set proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
        $$$ThrowOnError(proposal.%Save())
        Set resumeProposal = ##class(MyOwn.Agent.Proposal).%OpenId(resumed)
        Set resumeProposal.ResolvedAt = $ZDateTime($Horolog + 1, 3, 1)
        $$$ThrowOnError(resumeProposal.%Save())
        Set result = ..GateFor(decision, context, .decisionIds)
        Set ok = result.gate.createProposal
        Set details = details _ "after opposite action:" _ $Select(ok:"allowed", 1:"NOT allowed")
        Set passed = passed && ok
    } Catch exception {
        Set passed = 0
        Set details = details _ " " _ exception.DisplayString()
    }
    For index = 1:1:$ListLength(ids) Do ##class(MyOwn.Agent.Proposal).%DeleteId($List(ids, index))
    For index = 1:1:$ListLength(decisionIds) Do ##class(MyOwn.Agent.Decision).%DeleteId($List(decisionIds, index))
    Quit passed
}

ClassMethod GateFor(decision As %DynamicObject, context As %DynamicObject, ByRef decisionIds As %List) As %DynamicObject [ Private ]
{
    $$$ThrowOnError(##class(MyOwn.Agent.Service.Agent).ApplyGate("incident-triage", 0, "rules", "valid", decision.%ToJSON(), context.%ToJSON(), "dedup-test-" _ $System.Util.CreateGUID(), "", .result))
    Set decisionIds = decisionIds _ $ListBuild(result.decisionId)
    Quit result
}

ClassMethod TestProposal(kind As %String, target As %String, state As %String, createdAt As %TimeStamp, expiresAt As %TimeStamp, fingerprint As %String = "test") As %Integer [ Private ]
{
    Set proposal = ##class(MyOwn.Agent.Proposal).%New()
    Set proposal.DecisionId = 0
    Set proposal.Kind = kind
    Set proposal.TargetType = "task"
    Set proposal.TargetId = target
    Set proposal.Fingerprint = fingerprint
    Set proposal.State = state
    Set proposal.CreatedAt = createdAt
    Set proposal.ExpiresAt = expiresAt
    If state = "executed" Set proposal.ResolvedAt = createdAt
    $$$ThrowOnError(proposal.%Save())
    Quit proposal.%Id()
}

/// Timestamp <var>days</var> days before now (a negative value is in the future).
ClassMethod TimestampDaysAgo(days As %Integer) As %TimeStamp [ Private ]
{
    Quit $ZDateTime(($Piece($Horolog, ",", 1) - days) _ "," _ $Piece($Horolog, ",", 2), 3, 1)
}

/// Agent audit events recorded for <var>decisionId</var>, and whether any recent agent event
/// carries text that must never reach the audit log (model rationale or injected justification).
ClassMethod AgentAuditEvents(decisionId As %Integer, Output events As %List, Output leaked As %Boolean) As %Status [ Private ]
{
    Set events = ""
    Set leaked = 0
    New $Namespace
    Set $Namespace = "%SYS"
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT Event FROM %SYS.Audit WHERE EventSource = 'MyOwn' AND EventType = 'Agent' AND EventData %STARTSWITH ?")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute("agent=1;decisionId=" _ (+decisionId) _ ";")
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    While result.%Next() {
        If '$ListFind(events, result.%Get("Event")) Set events = events _ $ListBuild(result.%Get("Event"))
    }
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT COUNT(*) AS Leaks FROM %SYS.Audit WHERE EventSource = 'MyOwn' AND EventType = 'Agent' AND UTCTimeStamp > DATEADD(minute, -30, GETUTCDATE()) AND (EventData LIKE '%read-oriented%' OR EventData LIKE '%Ignore every policy%' OR EventData LIKE '%untrusted%' OR EventData LIKE '%rationale%')")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute()
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    If result.%Next() Set leaked = (result.%Get("Leaks") > 0)
    Quit $$$OK
}

ClassMethod Add(report As %DynamicObject, id As %String, passed As %Boolean, details As %String) As %Status [ Private ]
{
    Set item = {}
    Set item.id = id
    Set item.status = $Select(passed:"pass", 1:"fail")
    Set item.details = details
    Do report.results.%Push(item)
    If passed {
        Set report.pass = report.pass + 1
    } Else {
        Set report.fail = report.fail + 1
    }
    Quit $$$OK
}

ClassMethod RunIntegrationViaSQL() As %String [ SqlName = AgentIntegrationSmoke, SqlProc ]
{
    Set report = {}
    Set report.suite = "agents-integration-smoke"
    Set report.results = []
    Set report.pass = 0
    Set report.fail = 0

    Set tSC = ##class(MyOwn.Agent.Service.Agent).ProductionStatus(.production)
    Do ..Add(report, "IT-01", $$$ISOK(tSC) && production.running && (production.items.%Size() = 10), "The interoperability production is running with ten configured items.")

    Set tSC = ##class(MyOwn.Install.Scenarios).Run("S1", "", 0, "integration.test", .analysis)
    Do ..Add(report, "IT-02", $$$ISOK(tSC) && (analysis.engine = "rules") && (analysis.decision.action = "notify") && (analysis.integrationSource = "interoperability"), "Scenario S1 traverses the production and creates a deterministic rules decision.")

    Set tSC = ##class(MyOwn.Agent.Service.Agent).Trace(analysis.traceId, .trace)
    Do ..Add(report, "IT-02-TRACE", $$$ISOK(tSC) && (trace.timeline.%Size() >= 3), "The scenario trace links its event, decision, and execution ledger.")

    Set tSC = ##class(MyOwn.Install.Scenarios).Run("S10", "", 0, "integration.test", .budgetScenario)
    Set statement = ##class(%SQL.Statement).%New()
    Set prepareStatus = statement.%Prepare("SELECT COUNT(*) AS Matches FROM MyOwn_Agent.Notification WHERE Kind = 'budget' AND RefId = ?")
    If $$$ISOK(prepareStatus) Set notificationResult = statement.%Execute(budgetScenario.traceId)
    Set notified = 0
    If $$$ISOK(prepareStatus), notificationResult.%SQLCODE = 0, notificationResult.%Next() Set notified = (notificationResult.%Get("Matches") > 0)
    Do ..Add(report, "IT-11", $$$ISOK(tSC) && (budgetScenario.engine = "rules") && (budgetScenario.outcome = "budget_blocked") && notified, "Scenario S10 falls back to Rules and records a budget notification.")

    Set tSC = ##class(MyOwn.Install.Scenarios).Run("S7", "", 0, "integration.test", .prohibitedScenario)
    Do ..Add(report, "IT-07", $$$ISOK(tSC) && (prohibitedScenario.decision.action = "escalate") && ('prohibitedScenario.proposalId), "Scenario S7 denies a prohibited role without creating a proposal.")

    Set selfConfirmStatus = $$$ERROR($$$GeneralError, "NO_PROPOSAL")
    Set rejectStatus = $$$ERROR($$$GeneralError, "NO_PROPOSAL")
    Set tSC = ##class(MyOwn.Install.Scenarios).Run("S5", "", 0, "integration.requester", .accessScenario)
    If $$$ISOK(tSC), accessScenario.proposalId Set selfConfirmStatus = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(accessScenario.proposalId, "integration.requester", "", .selfConfirmation)
    Set separated = $$$ISERR(selfConfirmStatus) && ($System.Status.GetErrorText(selfConfirmStatus) [ "SEPARATION_OF_DUTIES")
    If $$$ISOK(tSC), accessScenario.proposalId Set rejectStatus = ##class(MyOwn.Agent.Service.Agent).RejectProposal(accessScenario.proposalId, "integration.admin", "test cleanup", .rejected)
    Do ..Add(report, "SEC-06", $$$ISOK(tSC) && (accessScenario.proposalId > 0) && separated && $$$ISOK(rejectStatus), "The requester cannot confirm their own low-risk access proposal.")

    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListDecisions(.decisions)
    Do ..Add(report, "IT-02-DECISION", $$$ISOK(tSC) && (decisions.%Size() > 0), "The decision is persisted and available to the REST facade.")

    Set tSC = ##class(MyOwn.Agent.Service.Agent).LedgerSummary(.ledger)
    Do ..Add(report, "IT-12", $$$ISOK(tSC) && (ledger.decisions > 0), "The observability ledger contains the decision execution.")

    Set tSC = ##class(MyOwn.Agent.Service.Agent).Guardrails(.guardrails)
    Do ..Add(report, "SEC-01", $$$ISOK(tSC) && guardrails.stateChangesRequireConfirmation && guardrails.agentToolsAreReadOnly, "The REST facade exposes the enforced human-confirmation and read-only-tool guardrails.")

    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListLedger(.entries)
    Do ..Add(report, "IT-12-LEDGER", $$$ISOK(tSC) && (entries.%Size() > 0), "Detailed execution ledger entries are available to administrators.")

    Set incident = ##class(MyOwn.Production.Msg.IncidentEvent).%New()
    Set incident.Source = "health"
    Set incident.TraceId = $System.Util.CreateGUID()
    Set tSC = ##class(Ens.Rule.Definition).EvaluateRules("MyOwn.Production.Rule.Routing", "", incident, "Integration test", .route, .reason)
    Set details = "The Business Rule routes a known operational source to incident triage."
    If $$$ISERR(tSC) Set details = details _ " " _ $System.Status.GetErrorText(tSC)
    Do ..Add(report, "IT-01-RULE", $$$ISOK(tSC) && (route = "incident-triage"), details)

    Set incident.Source = "untrusted-source"
    Set tSC = ##class(Ens.Rule.Definition).EvaluateRules("MyOwn.Production.Rule.Routing", "", incident, "Integration test", .route, .reason)
    Set details = "The Business Rule drops an unknown source before agent analysis."
    If $$$ISERR(tSC) Set details = details _ " " _ $System.Status.GetErrorText(tSC)
    Do ..Add(report, "SEC-ROUTING", $$$ISOK(tSC) && (route = "drop"), details)

    Set proposal = ##class(MyOwn.Agent.Proposal).%New()
    Set proposal.DecisionId = 0
    Set proposal.Kind = "role.assign"
    Set proposal.TargetType = "user-role"
    Set proposal.TargetId = "_SYSTEM|%All"
    Set proposal.Fingerprint = "forged"
    Set proposal.State = "pending"
    Set proposal.CreatedAt = $ZDateTime($Horolog, 3, 1)
    Set proposal.ExpiresAt = $ZDateTime(($Piece($Horolog, ",", 1) + 1) _ "," _ $Piece($Horolog, ",", 2), 3, 1)
    Set tSC = proposal.%Save()
    Set forgedId = proposal.%Id()
    If $$$ISOK(tSC) Set confirmStatus = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(forgedId, "security.test", "", .confirmation)
    Set blocked = $$$ISERR(confirmStatus) && ($System.Status.GetErrorText(confirmStatus) [ "PROHIBITED_TARGET")
    If forgedId Set cleanupStatus = ##class(MyOwn.Agent.Proposal).%DeleteId(forgedId)
    Do ..Add(report, "SEC-07", $$$ISOK(tSC) && blocked && $$$ISOK(cleanupStatus), "A forged proposal for a protected account and role is blocked before target lookup or mutation.")

    Set proposal = ##class(MyOwn.Agent.Proposal).%New()
    Set proposal.DecisionId = 0
    Set proposal.Kind = "task.suspend"
    Set proposal.TargetType = "task"
    Set proposal.TargetId = "999999"
    Set proposal.Fingerprint = "state-machine"
    Set proposal.State = "pending"
    Set proposal.CreatedAt = $ZDateTime($Horolog, 3, 1)
    Set proposal.ExpiresAt = $ZDateTime(($Piece($Horolog, ",", 1) + 1) _ "," _ $Piece($Horolog, ",", 2), 3, 1)
    Set tSC = proposal.%Save()
    Set proposalId = proposal.%Id()
    If $$$ISOK(tSC) Set rejectStatus = ##class(MyOwn.Agent.Service.Agent).RejectProposal(proposalId, "integration.test", "test rejection", .rejected)
    If $$$ISOK(rejectStatus) Set repeatedStatus = ##class(MyOwn.Agent.Service.Agent).RejectProposal(proposalId, "integration.test", "second rejection", .repeated)
    Set singleUse = $$$ISERR(repeatedStatus) && ($System.Status.GetErrorText(repeatedStatus) [ "PROPOSAL_ALREADY_RESOLVED")
    If proposalId Set cleanupStatus = ##class(MyOwn.Agent.Proposal).%DeleteId(proposalId)
    Do ..Add(report, "IT-04", $$$ISOK(tSC) && $$$ISOK(rejectStatus) && singleUse && $$$ISOK(cleanupStatus), "A proposal can be resolved only once.")

    ; An expired pending proposal is never listed as pending and becomes expired when proposals are read.
    Set overdue = ..TestProposal("task.suspend", "999991", "pending", ..TimestampDaysAgo(2), ..TimestampDaysAgo(1))
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ListProposals("pending", .pendingItems)
    Set listed = 0
    If $$$ISOK(tSC) {
        For index = 0:1:(pendingItems.%Size() - 1) {
            If pendingItems.%Get(index).id = overdue Set listed = 1
        }
    }
    Set overdueState = ##class(MyOwn.Agent.Proposal).StateGetStored(overdue)
    Do ##class(MyOwn.Agent.Proposal).%DeleteId(overdue)
    Do ..Add(report, "IT-17-EXPIRY", $$$ISOK(tSC) && 'listed && (overdueState = "expired"), "A pending proposal past ExpiresAt is not listed as pending and is marked expired when proposals are read.")

    ; Regression: expiry must not depend on the year only (timestamps were compared as numbers).
    Set expiryOk = ..ExpiryRegression(.expiryDetails)
    Do ..Add(report, "IT-19-EXPIRY-REGRESSION", expiryOk, "Proposals that expired hours earlier (same year and month) or a year earlier fail confirmation with PROPOSAL_EXPIRED and are not listed as pending. " _ expiryDetails)

    ; The Gate step never creates a second proposal for the same task and action.
    Set dedup = ..DedupScenario(.dedupDetails)
    Do ..Add(report, "IT-18-DEDUP", dedup, "No second proposal while one is pending or was executed within the cooldown; allowed after the cooldown or after the opposite action. " _ dedupDetails)

    ; Native audit (MyOwn/Agent/*) is written through a buffer that IRIS flushes in batches
    ; (observed 20-70 s locally, no public flush API), so poll up to 120 s for the S5 events.
    Set auditDecisionId = $Select($IsObject($Get(accessScenario)):+accessScenario.decisionId, 1:0)
    Set expectedEvents = $ListBuild("Decision", "ProposalCreated", "ProposalRejected")
    Set missing = "Decision, ProposalCreated, ProposalRejected"
    Set leaked = 0
    For attempt = 1:1:240 {
        Set tSC = ..AgentAuditEvents(auditDecisionId, .events, .leaked)
        If $$$ISERR(tSC) Quit
        Set missing = ""
        For index = 1:1:$ListLength(expectedEvents) {
            If '$ListFind(events, $List(expectedEvents, index)) Set missing = missing _ $Select(missing="":"", 1:", ") _ $List(expectedEvents, index)
        }
        Quit:missing=""
        Hang 0.5
    }
    Set details = "The S5 decision has Decision, ProposalCreated and ProposalRejected audit events marked agent=1 with its decision id, and no audit event contains model or justification text."
    If $$$ISERR(tSC) Set details = details _ " " _ $System.Status.GetErrorText(tSC)
    If missing '= "" Set details = details _ " Missing: " _ missing _ "."
    If leaked Set details = details _ " Model or justification text found in audit data."
    Do ..Add(report, "IT-14-AUDIT", $$$ISOK(tSC) && (auditDecisionId > 0) && (missing = "") && 'leaked, details)

    Set retention = ##class(MyOwn.Task.AgentRetention).%New()
    Set tSC = retention.OnTask()
    Set details = "The retention task completes successfully without deleting recent telemetry."
    If $$$ISERR(tSC) Set details = details _ " " _ $System.Status.GetErrorText(tSC)
    Do ..Add(report, "UT-08", $$$ISOK(tSC), details)

    Set report.summary = {}
    Set report.summary.pass = report.pass
    Set report.summary.fail = report.fail
    Quit report.%ToJSON()
}

}
