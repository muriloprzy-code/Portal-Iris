Class MyOwn.Agent.Policy.Gate
{

ClassMethod Evaluate(decision As %DynamicObject, context As %DynamicObject, config As MyOwn.Agent.Config, actor As %String, Output result As %DynamicObject) As %Status
{
    Set result = {}
    Set result.allowed = 1
    Set result.finalAction = decision.%Get("action")
    Set result.downgradedBy = ""
    Set result.createProposal = 0

    If config.KillSwitch {
        Set result.allowed = 0
        Set result.downgradedBy = "kill-switch"
        Quit $$$OK
    }
    If '##class(MyOwn.Agent.Decision.Schema).IsAllowedAction(decision.%Get("workflow"), decision.%Get("action")) {
        Set result.allowed = 0
        Set result.downgradedBy = "action-allow-list"
        Quit $$$OK
    }
    If (decision.%Get("workflow") = "access-request") && (context.%Get("riskFloor") = "high") && (result.finalAction = "approve") {
        Set result.finalAction = "escalate"
        Set result.downgradedBy = "high-risk-resource"
    }
    // An approval the model itself rates as high risk is incoherent; never turn it into a proposal.
    If (decision.%Get("workflow") = "access-request") && (decision.%Get("riskLevel") = "high") && (result.finalAction = "approve") {
        Set result.finalAction = "escalate"
        Set result.downgradedBy = "declared-high-risk"
    }
    Set targetType = decision.%Get("targetType")
    Set targetId = decision.%Get("targetId")
    If decision.%Get("workflow") = "access-request" {
        Set targetType = "role"
        Set targetId = decision.%Get("role")
    }
    Set manageable = context.%Get("manageable", 1)
    Set candidates = context.%Get("candidates")
    If (decision.%Get("workflow") = "incident-triage") && (targetType = "task") && $IsObject(candidates) {
        Set manageable = 0
        For index = 0:1:(candidates.%Size() - 1) {
            Set candidate = candidates.%Get(index)
            If $IsObject(candidate), candidate.%Get("id") = targetId Set manageable = +candidate.%Get("manageable")
        }
    }
    Set prohibited = ##class(MyOwn.Agent.Policy.Prohibited).Check("decision", targetType, targetId, context.%Get("requester"), actor, manageable, .reason)
    If prohibited {
        Set result.allowed = 0
        Set result.finalAction = "escalate"
        Set result.downgradedBy = "prohibited-target"
        Set result.reason = reason
        Quit $$$OK
    }
    If config.ReadOnly {
        Set result.createProposal = 0
        Set result.downgradedBy = $Select(result.downgradedBy="":"read-only", 1:result.downgradedBy)
        Quit $$$OK
    }
    Set proposalActions = "propose_task_run,propose_task_suspend,propose_task_resume,approve"
    Set result.createProposal = ($ListFind($ListFromString(proposalActions, ","), result.finalAction) > 0)
    Quit $$$OK
}

/// Proposal deduplication (needs the database, so it is kept out of Evaluate). Blocks a new
/// proposal when the same kind for the same target is still pending and not expired
/// (reason "duplicate-proposal"), or when the most recent executed proposal for that target
/// is of the same kind and was executed within CooldownMinutes ("recently-executed").
/// An opposite action (for example resume after a suspend) is not blocked.
ClassMethod CheckDuplicate(kind As %String, targetType As %String, targetId As %String, config As MyOwn.Agent.Config, Output existingId As %Integer, Output reason As %String, Output message As %String) As %Status
{
    Set existingId = 0
    Set reason = ""
    Set message = ""
    If (kind = "") || (targetId = "") Quit $$$OK
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 1 ID FROM MyOwn_Agent.Proposal WHERE Kind = ? AND TargetType = ? AND TargetId = ? AND State = 'pending' AND ExpiresAt >= ? ORDER BY ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(kind, targetType, targetId, $ZDateTime($Horolog, 3, 1))
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    If result.%Next() {
        Set existingId = result.%Get("ID")
        Set reason = "duplicate-proposal"
        Set message = "Proposal #" _ existingId _ " for this target is still pending."
        Quit $$$OK
    }
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT TOP 1 ID, Kind, ResolvedAt FROM MyOwn_Agent.Proposal WHERE TargetType = ? AND TargetId = ? AND State = 'executed' ORDER BY ResolvedAt DESC, ID DESC")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(targetType, targetId)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    If result.%Next(), $ZConvert(result.%Get("Kind"), "L") = $ZConvert(kind, "L") {
        Set cutoff = ..MinutesAgo(config.CooldownMinutes)
        ; String comparison: ODBC timestamps compared with ">=" would be compared as numbers.
        If '(cutoff ] result.%Get("ResolvedAt")) {
            Set existingId = result.%Get("ID")
            Set reason = "recently-executed"
            Set message = "Proposal #" _ existingId _ " already applied this action to the target within the last " _ config.CooldownMinutes _ " minutes."
        }
    }
    Quit $$$OK
}

ClassMethod MinutesAgo(minutes As %Integer) As %TimeStamp [ Private ]
{
    Set now = $Horolog
    Set seconds = $Piece(now, ",", 2) - (minutes * 60)
    Set days = +now
    While seconds < 0 {
        Set seconds = seconds + 86400
        Set days = days - 1
    }
    Quit $ZDateTime(days _ "," _ seconds, 3, 1)
}

ClassMethod CheckCooldown(fingerprint As %String, config As MyOwn.Agent.Config, Output suppressed As %Boolean) As %Status
{
    Set suppressed = 0
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT COUNT(*) AS Matches FROM MyOwn_Agent.Event WHERE Fingerprint = ? AND ReceivedAt >= DATEADD(minute, ?, CURRENT_TIMESTAMP)")
    If $$$ISERR(tSC) Quit tSC
    Set query = statement.%Execute(fingerprint, -config.CooldownMinutes)
    If query.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, query.%Message)
    If query.%Next() Set suppressed = (query.%Get("Matches") > 0)
    Quit $$$OK
}

}
