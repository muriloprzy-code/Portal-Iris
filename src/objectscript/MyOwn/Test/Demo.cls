/// Public demo checks: SELECT MyOwn_Test.DemoSmoke(). Demo mode is forced for this process only
/// (^||MyOwnDemo("mode")), so the suite also runs where MYOWN_DEMO_MODE is off. It changes only
/// synthetic targets and its own test proposals, and restores the synthetic seed at the end.
Class MyOwn.Test.Demo
{

/// waitAudit=0 returns the audit checks as "pending" with MyOwn_Test.DemoAuditCheck to poll.
ClassMethod Smoke(waitAudit As %Boolean = 1) As %String [ SqlName = DemoSmoke, SqlProc ]
{
    Set report = {"suite": "demo-smoke", "results": [], "pass": 0, "fail": 0}
    Set %MyOwnCheckAt = $ZHorolog
    Set previous = $Get(^||MyOwnDemo("mode"))
    Set ^||MyOwnDemo("mode") = 1
    Try {
        Do ..Checks(report, waitAudit)
    } Catch exception {
        Do ..Add(report, "DM-EXCEPTION", 0, exception.DisplayString())
    }
    Do ##class(MyOwn.Demo.Seed).Reset("test cleanup")
    If previous = "" { Kill ^||MyOwnDemo("mode") } Else { Set ^||MyOwnDemo("mode") = previous }
    Set report.summary = {"pass": (report.pass), "fail": (report.fail)}
    If +report.%Get("pending") Set report.summary.pending = report.pending
    Quit report.%ToJSON()
}

ClassMethod Checks(report As %DynamicObject, waitAudit As %Boolean) [ Private ]
{
    Set seed = "MyOwn.Demo.Seed"

    ; Reset restores the seed and is audited.
    Set tSC = $ClassMethod(seed, "Reset", "test")
    Set state = $ClassMethod(seed, "Summary")
    Set task = $ClassMethod(seed, "Task", 9001)
    Set ok = $$$ISOK(tSC) && (state.tasks.%Size() = 2) && (state.users.%Size() = 2) && (state.roles.%Size() = 2) && $IsObject(task) && (task.suspended = 0)
    Do ..AuditCheck(report, "DM-01-RESET", ok, "DemoReset", "test", waitAudit, "Reset restores two synthetic tasks, users and roles (task 9001 not suspended) and records a DemoReset audit event.")

    ; Which targets are synthetic.
    Set synthetic = ..Proposal("task", "9001", "task.suspend")
    Set realTask = ..Proposal("task", "1", "task.suspend")
    Set syntheticRole = ..Proposal("user-role", "demo.alice|DemoOperator", "role.assign")
    Set realUser = ..Proposal("user-role", "_SYSTEM|DemoOperator", "role.assign")
    Set realRole = ..Proposal("user-role", "demo.alice|%All", "role.assign")
    Set ok = $ClassMethod(seed, "IsSynthetic", synthetic) && '$ClassMethod(seed, "IsSynthetic", realTask) && $ClassMethod(seed, "IsSynthetic", syntheticRole) && '$ClassMethod(seed, "IsSynthetic", realUser) && '$ClassMethod(seed, "IsSynthetic", realRole)
    Do ..Add(report, "DM-02-SYNTHETIC", ok, "Only seeded tasks, and assignments of a seeded role to a seeded user, count as synthetic targets.")

    ; A confirmation on a real target is refused, audited, and leaves the proposal pending.
    Set real = ..SavedProposal("task", "1", "task.suspend")
    Set tSC = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(real.%Id(), "demo", "", .data)
    Set refused = $$$ISERR(tSC) && ($System.Status.GetErrorText(tSC) [ "DEMO_TARGET_REFUSED")
    Set stillPending = (##class(MyOwn.Agent.Proposal).%OpenId(real.%Id()).State = "pending")
    Do ..AuditCheck(report, "DM-03-REAL-REFUSED", refused && stillPending, "DemoRefused", "proposal " _ real.%Id(), waitAudit, "Confirming a proposal on a real task in demo mode is refused (DEMO_TARGET_REFUSED), the proposal stays pending, and a DemoRefused audit event is recorded.")
    Do ##class(MyOwn.Agent.Proposal).%DeleteId(real.%Id())

    ; S2 in demo mode targets the synthetic task; confirming it changes only that record.
    Set tSC = ##class(MyOwn.Install.Scenarios).Run("S2", "", 0, "demo", .response)
    Set proposalId = $Select($$$ISOK(tSC): +response.%Get("proposalId"), 1: 0)
    Set targetId = $Select(proposalId: ##class(MyOwn.Agent.Proposal).%OpenId(proposalId).TargetId, 1: "")
    Set confirmStatus = $$$ERROR($$$GeneralError, "NO_PROPOSAL")
    If proposalId Set confirmStatus = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(proposalId, "demo", "", .confirmed)
    Set after = $ClassMethod(seed, "Task", 9001)
    Set state = $Select(proposalId: ##class(MyOwn.Agent.Proposal).%OpenId(proposalId).State, 1: "")
    Set details = "S2 proposes suspending synthetic task 9001; the confirmation ends as 'simulated' and only the synthetic record is suspended."
    If $$$ISERR(confirmStatus) Set details = details _ " " _ $System.Status.GetErrorText(confirmStatus)
    Do ..Add(report, "DM-04-SIMULATED", $$$ISOK(tSC) && (targetId = "9001") && $$$ISOK(confirmStatus) && (state = "simulated") && $IsObject(after) && (after.suspended = 1), details)

    ; S5 in demo mode: a synthetic requester asks for a synthetic role.
    Set tSC = ##class(MyOwn.Install.Scenarios).Run("S5", "", 0, "demo", .access)
    Set proposalId = $Select($$$ISOK(tSC): +access.%Get("proposalId"), 1: 0)
    Set proposal = $Select(proposalId: ##class(MyOwn.Agent.Proposal).%OpenId(proposalId), 1: "")
    Set confirmStatus = $$$ERROR($$$GeneralError, "NO_PROPOSAL")
    If $IsObject(proposal) Set confirmStatus = ##class(MyOwn.Agent.Service.Agent).ConfirmProposal(proposalId, "demo", "", .confirmed)
    Set roles = ##class(MyOwn.Demo.Seed).Summary().users.%Get(0).roles.%ToJSON()
    Do ..Add(report, "DM-05-ROLE", $IsObject(proposal) && (proposal.TargetId = "demo.alice|DemoOperator") && $$$ISOK(confirmStatus) && (roles [ "DemoOperator"), "S5 asks for DemoOperator on behalf of demo.alice; the demo account can confirm it and only the synthetic user gets the role.")

    ; Rate limit per key.
    Set key = "test:" _ $System.Util.CreateGUID()
    Set allowed = 0
    For attempt = 1:1:7 {
        If ##class(MyOwn.Demo.RateLimit).Allow(key, 6, .retryAfter) Set allowed = allowed + 1
    }
    Do ##class(MyOwn.Demo.RateLimit).Clear(key)
    Do ..Add(report, "DM-06-RATE", (allowed = 6) && (retryAfter > 0) && (retryAfter <= 60), "Six uses per minute are allowed for one key; the seventh is refused with a Retry-After of at most 60 s.")

    ; The %SYS-side literals of MyOwn.Demo.Setup match their sources.
    Set same = (##class(MyOwn.Demo.Setup).#DemoRole = ##class(MyOwn.Demo.Mode).#DemoRole) && (##class(MyOwn.Demo.Setup).#ResetTaskName = ##class(MyOwn.Task.DemoReset).#TaskName)
    Do ..Add(report, "DM-08-LITERALS", same, "MyOwn.Demo.Setup uses the same demo role and reset task names as MyOwn.Demo.Mode and MyOwn.Task.DemoReset.")

    ; Reset after the changes restores the seed.
    Do $ClassMethod(seed, "Reset", "test")
    Set task = $ClassMethod(seed, "Task", 9001)
    Set roles = ##class(MyOwn.Demo.Seed).Summary().users.%Get(0).roles.%ToJSON()
    Do ..Add(report, "DM-07-RESTORE", $IsObject(task) && (task.suspended = 0) && (roles = "[]"), "After the confirmations, a reset puts task 9001 and demo.alice back to their seed state.")
}

ClassMethod Proposal(targetType As %String, targetId As %String, kind As %String) As MyOwn.Agent.Proposal [ Private ]
{
    Set proposal = ##class(MyOwn.Agent.Proposal).%New()
    Set proposal.TargetType = targetType
    Set proposal.TargetId = targetId
    Set proposal.Kind = kind
    Quit proposal
}

ClassMethod SavedProposal(targetType As %String, targetId As %String, kind As %String) As MyOwn.Agent.Proposal [ Private ]
{
    Set proposal = ..Proposal(targetType, targetId, kind)
    Set proposal.DecisionId = 0
    Set proposal.State = "pending"
    Set proposal.Fingerprint = "test"
    Set proposal.CreatedAt = $ZDateTime($Horolog, 3, 1)
    Set proposal.ExpiresAt = $ZDateTime($Horolog + 1, 3, 1)
    $$$ThrowOnError(proposal.%Save())
    Quit proposal
}

/// Test helper for scripts/Test-AgentDemo.ps1: a pending proposal on a real task (id 1).
ClassMethod RealProposal() As %Integer [ SqlName = DemoRealProposal, SqlProc ]
{
    Quit ..SavedProposal("task", "1", "task.suspend").%Id()
}

/// One poll: {"done", "pass"} for a MyOwn/Agent audit event whose data contains marker.
ClassMethod AuditCheck2(event As %String, marker As %String) As %String [ SqlName = DemoAuditCheck, SqlProc ]
{
    Set found = ..AuditFound(event, marker, 1)
    Quit {"done": (found), "pass": (found)}.%ToJSON()
}

ClassMethod AuditCheck(report As %DynamicObject, id As %String, passed As %Boolean, event As %String, marker As %String, waitAudit As %Boolean, details As %String) [ Private ]
{
    If 'passed Do ..Add(report, id, 0, details)  Quit
    If ..AuditFound(event, marker, $Select(waitAudit: 120, 1: 1)) Do ..Add(report, id, 1, details)  Quit
    If waitAudit Do ..Add(report, id, 0, details _ " The audit event was not visible after 60 s.")  Quit
    Set now = $ZHorolog
    Do report.results.%Push({"id": (id), "status": "pending", "details": (details), "poll": {"proc": "MyOwn_Test.DemoAuditCheck", "args": [(event), (marker)]}, "durationMs": ((now - $Get(%MyOwnCheckAt, now)) * 1000 \ 1)})
    Set %MyOwnCheckAt = now
    Set report.pending = +report.%Get("pending") + 1
}

/// Polls %SYS.Audit for a MyOwn/Agent event whose data contains marker, attempts times 0.5 s apart.
ClassMethod AuditFound(event As %String, marker As %String, attempts As %Integer) As %Boolean [ Private ]
{
    New $Namespace
    Set $Namespace = "%SYS"
    Set statement = ##class(%SQL.Statement).%New()
    If $$$ISERR(statement.%Prepare("SELECT COUNT(*) AS Matches FROM %SYS.Audit WHERE EventSource = 'MyOwn' AND EventType = 'Agent' AND Event = ? AND EventData [ ? AND UTCTimeStamp > DATEADD(minute, -30, GETUTCDATE())")) Quit 0
    Set found = 0
    For attempt = 1:1:attempts {
        Set rows = statement.%Execute(event, marker)
        If rows.%Next() && (rows.%Get("Matches") > 0) Set found = 1
        Quit:found
        If attempt < attempts Hang 0.5
    }
    Quit found
}

ClassMethod Add(report As %DynamicObject, id As %String, passed As %Boolean, details As %String) [ Private ]
{
    Set now = $ZHorolog
    Do report.results.%Push({"id": (id), "status": ($Select(passed: "pass", 1: "fail")), "details": (details), "durationMs": ((now - $Get(%MyOwnCheckAt, now)) * 1000 \ 1)})
    Set %MyOwnCheckAt = now
    If passed {
        Set report.pass = report.pass + 1
    } Else {
        Set report.fail = report.fail + 1
    }
}

}
