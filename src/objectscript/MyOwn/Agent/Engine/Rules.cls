Class MyOwn.Agent.Engine.Rules Extends MyOwn.Agent.Engine.Base
{

ClassMethod Decide(workflow As %String, contextJSON As %String, Output result As %DynamicObject) As %Status
{
    Set result = {}
    Set tSC = $$$OK
    Try {
        Set context = {}.%FromJSON(contextJSON)
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    If workflow = "incident-triage" {
        Set decision = ..DecideTriage(context)
    } ElseIf workflow = "access-request" {
        Set decision = ..DecideAccess(context)
    } Else {
        Quit $$$ERROR($$$GeneralError, "Unsupported agent workflow")
    }
    Set result.decision = decision
    Set result.engine = "rules"
    Set result.provider = ""
    Set result.model = ""
    Set result.outcome = "ok"
    Set result.usage = {}
    Set result.usage.promptTokens = 0
    Set result.usage.completionTokens = 0
    Set result.usage.totalTokens = 0
    Set result.toolCalls = []
    Quit $$$OK
}

ClassMethod DecideTriage(context As %DynamicObject) As %DynamicObject [ Private ]
{
    Set decision = ..TriageBase()
    Set task = context.%Get("task")
    If $IsObject(task) {
        Set decision.targetType = "task"
        Set decision.targetId = task.%Get("id")
        If task.%Get("consecutiveFailures") >= 3 {
            Set decision.action = "propose_task_suspend"
            Set decision.severity = "critical"
            Set decision.rationale = "The task has failed at least three consecutive times. Suspending it prevents repeated failures while an administrator investigates."
            Set decision.confidence = 0.95
            Do ..AddEvidence(decision, "task", task.%Get("id"))
            Set decision.recommendedFollowUp = "Inspect the most recent task error before confirming the suspension."
            Quit decision
        }
        If task.%Get("suspended"), task.%Get("lastRunOk") {
            Set decision.action = "propose_task_resume"
            Set decision.severity = "warning"
            Set decision.rationale = "The task is suspended even though its last recorded execution completed successfully."
            Set decision.confidence = 0.85
            Do ..AddEvidence(decision, "task", task.%Get("id"))
            Set decision.recommendedFollowUp = "Confirm that the task should return to its normal schedule."
            Quit decision
        }
    }

    Set anomalies = context.%Get("anomalies")
    Set highest = 0
    Set highestMetric = ""
    Set highestSeverity = "info"
    If $IsObject(anomalies) {
        For index = 0:1:(anomalies.%Size() - 1) {
            Set anomaly = anomalies.%Get(index)
            If $IsObject(anomaly), anomaly.%Get("zScore") > highest {
                Set highest = anomaly.%Get("zScore")
                Set highestMetric = anomaly.%Get("metric")
                Set highestSeverity = anomaly.%Get("severity")
            }
        }
    }
    If highest > 2 {
        Set decision.action = "notify"
        Set decision.severity = $Select(highest>3:"critical", 1:"warning")
        Set decision.rationale = "The current metric is above its recent statistical baseline and should be reviewed by an operator."
        Set decision.confidence = $Select(highest>3:0.95, 1:0.8)
        Do ..AddEvidence(decision, "anomaly", highestMetric)
        Set decision.recommendedFollowUp = "Review the health report and related logs before taking corrective action."
    } ElseIf context.%Get("thresholdExceeded") {
        Set decision.action = "notify"
        Set decision.severity = context.%Get("thresholdSeverity", "warning")
        Set decision.rationale = "A deterministic health threshold was exceeded, but there is not enough evidence for an automatic task proposal."
        Set decision.confidence = 0.75
        Do ..AddEvidence(decision, "anomaly", context.%Get("thresholdMetric", "health"))
        Set decision.recommendedFollowUp = "Review the current health metrics and confirm whether intervention is needed."
    } Else {
        Set decision.action = "ignore"
        Set decision.rationale = "No actionable anomaly or repeat task failure was found in the supplied context."
        Set decision.confidence = 0.9
        Set decision.recommendedFollowUp = "Continue normal monitoring."
    }
    Quit decision
}

ClassMethod DecideAccess(context As %DynamicObject) As %DynamicObject [ Private ]
{
    Set decision = {}
    Set decision.schemaVersion = 1
    Set decision.workflow = "access-request"
    Set decision.user = context.%Get("requester")
    Set decision.role = context.%Get("roleRequested")
    Set decision.evidence = []
    Set decision.conditions = []
    Set floor = context.%Get("riskFloor", "low")
    Set delta = context.%Get("deltaLevel", "medium")
    If (floor = "high") || (delta = "high") {
        Set decision.action = $Select(context.%Get("prohibited"):"deny", 1:"escalate")
        Set decision.riskLevel = "high"
        Set decision.rationale = "The requested role adds high-risk privileges and requires explicit administrator review."
        Set decision.confidence = 0.95
    } ElseIf delta = "low" {
        Set decision.action = "approve"
        Set decision.riskLevel = "low"
        Set decision.rationale = "The requested role adds only low-risk, read-oriented privileges according to the server-calculated delta."
        Set decision.confidence = 0.9
        Do decision.conditions.%Push("Review the assignment if the user's responsibilities change.")
    } Else {
        Set decision.action = "escalate"
        Set decision.riskLevel = "medium"
        Set decision.rationale = "The privilege delta is material and should be reviewed by an administrator before assignment."
        Set decision.confidence = 0.8
    }
    Set evidence = {}
    Set evidence.source = "privilege-delta"
    Set evidence.ref = context.%Get("roleRequested")
    Do decision.evidence.%Push(evidence)
    Quit decision
}

ClassMethod TriageBase() As %DynamicObject [ Private ]
{
    Set decision = {}
    Set decision.schemaVersion = 1
    Set decision.workflow = "incident-triage"
    Set decision.action = "ignore"
    Set decision.severity = "info"
    Set decision.targetType = "none"
    Set decision.targetId = ""
    Set decision.rationale = ""
    Set decision.confidence = 0
    Set decision.evidence = []
    Set decision.recommendedFollowUp = ""
    Quit decision
}

ClassMethod AddEvidence(decision As %DynamicObject, source As %String, reference As %String) As %Status [ Private ]
{
    Set evidence = {}
    Set evidence.source = source
    Set evidence.ref = reference
    Do decision.evidence.%Push(evidence)
    Quit $$$OK
}

}
