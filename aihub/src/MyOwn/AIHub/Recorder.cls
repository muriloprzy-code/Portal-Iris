/// Records a replay fixture from one real model decision: the exact context of a demonstration
/// scenario (MyOwn.Install.Scenarios.BuildContext) goes through the live engine, the answer must
/// pass the Validator, and the call is written to the ledger like any AI call, so it counts for
/// the hourly limit and the token budget. Nothing goes through the production and no proposal is
/// created. Used by scripts/Record-ReplayFixtures.ps1.
Class MyOwn.AIHub.Recorder
{

/// Returns the fixture JSON (status "recorded") or {"scenario", "status": "failed", "reason", "detail"}.
/// authorization is needed only for S2/S3 (the demonstration task is read through SysAdmin).
ClassMethod Record(scenario As %String, authorization As %String = "", taskId As %Integer = 0, requester As %String = "demo.viewer") As %String [ SqlName = RecordScenario, SqlProc ]
{
    Set scenario = $ZConvert(##class(MyOwn.Agent.Sanitize).Identifier(scenario, 4), "U")
    Set failed = {"scenario": (scenario), "status": "failed"}
    If ##class(MyOwn.Agent.AIEnv).Mode() '= "live" Quit ..Failed(failed, "not_live", "set MYOWN_AI_MODE=live to record")
    If '##class(MyOwn.AIHub.Engine).Ready(.reason) Quit ..Failed(failed, reason, "provider, model or key not configured")
    If scenario = "S10" Quit ..Failed(failed, "not_applicable", "the budget check stops S10 before any AI call")
    Set tSC = ##class(MyOwn.Agent.Config).GetOrCreate(.config)
    If $$$ISERR(tSC) Quit ..Failed(failed, "config", $System.Status.GetErrorText(tSC))
    If config.KillSwitch Quit ..Failed(failed, "kill_switch", "the kill switch is on")
    Set tSC = ##class(MyOwn.Agent.Policy.Budget).CallsAllowed(config, .allowed, .recent)
    If $$$ISERR(tSC) || 'allowed Quit ..Failed(failed, "budget", "hourly AI call limit reached (" _ recent _ ")")
    Set tSC = ##class(MyOwn.Install.Scenarios).BuildContext(scenario, authorization, taskId, requester, .workflow, .context)
    If $$$ISERR(tSC) Quit ..Failed(failed, "context", $System.Status.GetErrorText(tSC))
    Set contextJSON = context.%ToJSON()

    Set started = $ZDateTime($Horolog, 3, 1)
    Set recordedAt = $Translate($ZDateTime($ZTimestamp, 3, 1), " ", "T") _ "Z"
    Set callStatus = ##class(MyOwn.AIHub.Engine).Decide(workflow, contextJSON, .result)
    Set reason = "", detail = ""
    If $$$ISERR(callStatus) {
        Set text = $System.Status.GetErrorText(callStatus)
        Set reason = $Select(text [ "AIHUB_FALLBACK:": $Piece($Piece(text, "AIHUB_FALLBACK:", 2), ":", 1), 1: "provider_error")
        Set detail = $Piece(text, "AIHUB_FALLBACK:", 2)
    } Else {
        Set validStatus = ##class(MyOwn.Agent.Decision.Validator).Validate(workflow, result.%Get("raw"), contextJSON, .decision, .errors)
        If $$$ISERR(validStatus) Set reason = "invalid_json", detail = $Select($IsObject(errors) && (errors.%Size() > 0): errors.%Get(0), 1: "")
    }
    Do ..SaveLedger(workflow, scenario, result, started, $Select(reason = "": "ok", 1: reason), detail)
    ; Tool calls (also those made before a deadline) show where the time went.
    Set calls = $Select($IsObject($Get(result)) && $IsObject(result.%Get("toolCalls")): result.toolCalls, 1: [])
    Set failed.toolCalls = calls
    If reason '= "" Quit ..Failed(failed, reason, detail)

    Set raw = result.raw
    Set substitutions = []
    Set taskValue = $Select($IsObject(context.%Get("task")): context.task.%Get("id"), 1: "")
    For pair = $ListBuild(taskValue, "{{taskId}}"), $ListBuild(context.%Get("requester"), "{{requester}}"), $ListBuild(context.%Get("roleRequested"), "{{roleRequested}}") {
        Set value = $ZConvert($List(pair, 1), "O", "JSON")
        If (value '= "") && (raw [ value) {
            Set raw = $Replace(raw, value, $List(pair, 2))
            Do substitutions.%Push($List(pair, 1) _ " -> " _ $List(pair, 2))
        }
    }
    Set fixture = {"scenario": (scenario), "status": "recorded", "provider": (result.%Get("provider")), "model": (result.%Get("model")), "recordedAt": (recordedAt)}
    Set fixture.source = "real call recorded by scripts/Record-ReplayFixtures.ps1"
    Set fixture.context = "Exact " _ scenario _ " context (MyOwn.Install.Scenarios.BuildContext)."
    Set fixture.substitutions = substitutions
    Set fixture.latencyMs = +result.%Get("latencyMs")
    Set fixture.usage = result.%Get("usage")
    Set fixture.iterations = +result.%Get("iterations")
    If calls.%Size() > 0 Set fixture.toolCallsDuringRecording = calls
    Set fixture.raw = raw
    Quit fixture.%ToJSON()
}

ClassMethod Failed(failed As %DynamicObject, reason As %String, detail As %String) As %String [ Private ]
{
    Set failed.reason = reason
    Set failed.detail = $Extract(##class(MyOwn.Agent.Sanitize).Text(detail, 300), 1, 300)
    Quit failed.%ToJSON()
}

ClassMethod SaveLedger(workflow As %String, scenario As %String, result As %DynamicObject, started As %TimeStamp, outcome As %String, detail As %String) [ Private ]
{
    If '$IsObject($Get(result)) Set result = {}
    Set ledger = ##class(MyOwn.Agent.Ledger).%New()
    Set ledger.TraceId = "record-" _ scenario _ "-" _ $System.Util.CreateGUID()
    Set ledger.Workflow = workflow
    Set ledger.Engine = "aihub"
    Set ledger.Provider = result.%Get("provider")
    Set ledger.Model = result.%Get("model")
    Set ledger.StartedAt = started
    Set ledger.DurationMs = +result.%Get("latencyMs")
    Set usage = result.%Get("usage")
    If $IsObject(usage) {
        Set ledger.PromptTokens = +usage.%Get("promptTokens")
        Set ledger.CompletionTokens = +usage.%Get("completionTokens")
        Set ledger.TotalTokens = +usage.%Get("totalTokens")
    }
    Set ledger.Iterations = +result.%Get("iterations")
    Set ledger.Outcome = $Extract(outcome, 1, 30)
    Set ledger.ErrorSummary = ##class(MyOwn.Agent.Sanitize).Text("recording " _ scenario _ $Select(detail '= "": ": " _ detail, 1: ""), 500)
    Set billedOutput = ledger.CompletionTokens
    If ledger.TotalTokens > (ledger.PromptTokens + ledger.CompletionTokens) Set billedOutput = ledger.TotalTokens - ledger.PromptTokens
    If $$$ISOK(##class(MyOwn.Agent.Pricing).Estimate(ledger.Model, ledger.PromptTokens, billedOutput, .cost, .hasPrice)), hasPrice Set ledger.CostEstimateUSD = cost
    Do ledger.%Save()
}

}
