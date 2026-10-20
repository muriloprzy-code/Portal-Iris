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
