Class MyOwn.Agent.Decision.Schema
{

ClassMethod AllowedActions(workflow As %String) As %String
{
    If workflow = "incident-triage" Quit "ignore,notify,propose_task_run,propose_task_suspend,propose_task_resume,escalate"
    If workflow = "access-request" Quit "approve,deny,escalate"
    Quit ""
}

ClassMethod IsAllowedAction(workflow As %String, action As %String) As %Boolean
{
    Quit $ListFind($ListFromString(..AllowedActions(workflow), ","), action) > 0
}

ClassMethod Guardrails(Output data As %DynamicObject) As %Status
{
    Set data = {}
    Set data.schemaVersion = 1
    Set data.workflows = []
    Set triage = {}
    Set triage.name = "incident-triage"
    Set triage.actions = [].%FromJSON("[""ignore"",""notify"",""propose_task_run"",""propose_task_suspend"",""propose_task_resume"",""escalate""]")
    Do data.workflows.%Push(triage)
    Set access = {}
    Set access.name = "access-request"
    Set access.actions = [].%FromJSON("[""approve"",""deny"",""escalate""]")
    Do data.workflows.%Push(access)
    Quit $$$OK
}

}
