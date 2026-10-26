/// Synthetic state of the public demo: two tasks, two users and two roles that exist only in
/// MyOwn.Demo.Target. Demo scenarios point at them, confirmations change only them, and Reset()
/// restores the seed (on a schedule and from the "Reset demo" button).
Class MyOwn.Demo.Seed
{

/// The synthetic user who files the demo access requests (so the demo account can confirm them).
Parameter Requester = "demo.alice";

/// Synthetic task that keeps failing (S2) and synthetic suspended task whose last run was ok (S3).
Parameter FailingTaskId = 9001;

Parameter RecoveredTaskId = 9002;

XData Definition [ MimeType = application/json ]
{
{
  "tasks": [
    {"id": 9001, "name": "Demo: nightly export", "suspended": 0, "manageable": 1, "consecutiveFailures": 3, "lastRunOk": 0},
    {"id": 9002, "name": "Demo: cache warmer", "suspended": 1, "manageable": 1, "consecutiveFailures": 0, "lastRunOk": 1}
  ],
  "users": [
    {"user": "demo.alice", "roles": []},
    {"user": "demo.bob", "roles": ["DemoAuditor"]}
  ],
  "roles": [
    {"role": "DemoOperator", "description": "Synthetic operator role of the public demo."},
    {"role": "DemoAuditor", "description": "Synthetic read-only role of the public demo."}
  ]
}
}

/// Restores the seed, expires pending proposals on synthetic targets, and audits the reset.
ClassMethod Reset(source As %String) As %Status
{
    Set tSC = ..Load()
    If $$$ISERR(tSC) Quit tSC
    Set expired = 0
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT ID FROM MyOwn_Agent.Proposal WHERE State = 'pending'")
    If $$$ISERR(tSC) Quit tSC
    Set rows = statement.%Execute()
    While rows.%Next() {
        Set proposal = ##class(MyOwn.Agent.Proposal).%OpenId(rows.%Get("ID"))
        If '$IsObject(proposal) || '..IsSynthetic(proposal) Continue
        Set proposal.State = "expired"
        Set proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
        Set proposal.ResultMessage = "The demo was reset to its initial state."
        Set tSC = proposal.%Save()
        If $$$ISERR(tSC) Quit
        Set expired = expired + 1
    }
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(MyOwn.Service.Audit).RecordAgent("DemoReset", 0, "synthetic targets", 1, $Extract(source, 1, 20) _ ", " _ expired _ " pending expired", 0)
}

/// Loads the seed when the table is empty (installation and container start).
ClassMethod EnsureSeeded() As %Status
{
    If $Order(^MyOwn.Demo.TargetD("")) '= "" Quit $$$OK
    Quit ..Load()
}

ClassMethod Load() As %Status [ Private ]
{
    Set xdata = ##class(%Dictionary.CompiledXData).%OpenId($ClassName() _ "||Definition")
    If '$IsObject(xdata) Quit $$$ERROR($$$GeneralError, "demo seed not found")
    Set seed = {}.%FromJSON(xdata.Data)
    Set tSC = ##class(MyOwn.Demo.Target).%KillExtent()
    If $$$ISERR(tSC) Quit tSC
    Set namespace = $ZConvert($Namespace, "U")
    For kind = "tasks", "users", "roles" {
        Set items = seed.%Get(kind)
        For index = 0:1:(items.%Size() - 1) {
            Set item = items.%Get(index)
            Set target = ##class(MyOwn.Demo.Target).%New()
            Set target.Kind = $Extract(kind, 1, *-1)
            If kind = "tasks" {
                Set item.namespace = namespace
                Set target.Name = item.name
                Set target.TaskId = item.id
            } Else {
                Set target.Name = $Select(kind = "users": item.user, 1: item.role)
            }
            Set target.StateJSON = item.%ToJSON()
            Set tSC = target.%Save()
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// A synthetic task as the scenarios and the TaskWatcher shape it ("" when not synthetic).
ClassMethod Task(taskId As %Integer) As %DynamicObject
{
    Set id = $Order(^MyOwn.Demo.TargetI("TaskIdIndex", +taskId, ""))
    If id = "" Quit ""
    Set target = ##class(MyOwn.Demo.Target).%OpenId(id)
    Quit $Select($IsObject(target): {}.%FromJSON(target.StateJSON), 1: "")
}

/// Whether a proposal targets only synthetic records (task, or user and role of an assignment).
ClassMethod IsSynthetic(proposal As MyOwn.Agent.Proposal) As %Boolean
{
    If proposal.TargetType = "task" Quit $IsObject(..Task(proposal.TargetId))
    If proposal.TargetType = "user-role" Quit $IsObject(..Find("user", $Piece(proposal.TargetId, "|", 1))) && $IsObject(..Find("role", $Piece(proposal.TargetId, "|", 2)))
    Quit 0
}

/// Current state of a synthetic target, shaped like the live read of ConfirmProposal.
ClassMethod ReadTarget(proposal As MyOwn.Agent.Proposal, Output current As %DynamicObject, Output manageable As %Boolean) As %Status
{
    Set current = "", manageable = 0
    If proposal.TargetType = "task" {
        Set task = ..Task(proposal.TargetId)
        If '$IsObject(task) Quit $$$ERROR($$$GeneralError, "DEMO_TARGET_REFUSED")
        Set manageable = +task.%Get("manageable")
        Set current = {"id": (+task.id), "name": (task.name), "namespace": ($ZConvert(task.namespace, "U")), "suspended": (+task.suspended), "manageable": (manageable)}
        Quit $$$OK
    }
    If proposal.TargetType = "user-role" {
        Set target = ..Find("user", $Piece(proposal.TargetId, "|", 1))
        If '$IsObject(target) Quit $$$ERROR($$$GeneralError, "DEMO_TARGET_REFUSED")
        Set state = {}.%FromJSON(target.StateJSON)
        Set manageable = 1
        Set current = {"user": (state.user), "roles": (state.roles)}
        Quit $$$OK
    }
    Quit $$$ERROR($$$GeneralError, "DEMO_TARGET_REFUSED")
}

/// Applies a confirmed proposal to its synthetic target only (IRIS is not changed).
ClassMethod Apply(proposal As MyOwn.Agent.Proposal, Output result As %DynamicObject) As %Status
{
    Set result = {"simulated": 1, "message": "Demo mode: the change was applied to the synthetic target only; IRIS was not changed."}
    If proposal.TargetType = "task" {
        Set id = $Order(^MyOwn.Demo.TargetI("TaskIdIndex", +proposal.TargetId, ""))
        Set target = ##class(MyOwn.Demo.Target).%OpenId(id)
        If '$IsObject(target) Quit $$$ERROR($$$GeneralError, "DEMO_TARGET_REFUSED")
        Set state = {}.%FromJSON(target.StateJSON)
        If proposal.Kind = "task.suspend" Set state.suspended = 1
        If proposal.Kind = "task.resume" Set state.suspended = 0
        If proposal.Kind = "task.run" Set state.lastRunOk = 1, state.consecutiveFailures = 0
        Set target.StateJSON = state.%ToJSON()
        Quit target.%Save()
    }
    If proposal.Kind = "role.assign" {
        Set target = ..Find("user", $Piece(proposal.TargetId, "|", 1))
        If '$IsObject(target) || '$IsObject(..Find("role", $Piece(proposal.TargetId, "|", 2))) Quit $$$ERROR($$$GeneralError, "DEMO_TARGET_REFUSED")
        Set state = {}.%FromJSON(target.StateJSON)
        Set role = $Piece(proposal.TargetId, "|", 2)
        Set found = 0
        For index = 0:1:(state.roles.%Size() - 1) {
            If state.roles.%Get(index) = role Set found = 1
        }
        If 'found Do state.roles.%Push(role)
        Set target.StateJSON = state.%ToJSON()
        Quit target.%Save()
    }
    Quit $$$ERROR($$$GeneralError, "DEMO_TARGET_REFUSED")
}

/// Synthetic targets for the screen: {tasks, users, roles}.
ClassMethod Summary() As %DynamicObject
{
    Set data = {"tasks": [], "users": [], "roles": []}
    Set id = ""
    For {
        Set id = $Order(^MyOwn.Demo.TargetD(id))
        If id = "" Quit
        Set target = ##class(MyOwn.Demo.Target).%OpenId(id)
        If '$IsObject(target) Continue
        Do data.%Get(target.Kind _ "s").%Push({}.%FromJSON(target.StateJSON))
    }
    Quit data
}

ClassMethod Find(kind As %String, name As %String) As MyOwn.Demo.Target [ Private ]
{
    Quit ##class(MyOwn.Demo.Target).KindNameIndexOpen(kind, name)
}

}
