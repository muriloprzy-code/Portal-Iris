/// AI Hub engine for MyOwn.Agent.Service.Agent. Configuration comes only from the environment
/// (MyOwn.Agent.AIEnv). Each decision runs in a worker job so the portal can enforce its own
/// deadline: the provider call itself cannot be interrupted (the session timeout_ms is checked
/// only between iterations), so on timeout the worker is terminated and the caller decides
/// with Rules.
/// <p>Decide returns result {raw, provider, model, usage{promptTokens, completionTokens,
/// totalTokens}, latencyMs, iterations, toolCalls[{name, args, summary, durationMs, status}],
/// replayCase}; on failure it returns an error "AIHUB_FALLBACK:reason:detail" with reason
/// provider_timeout, provider_error or no_key, and result still carries what is known (latency,
/// tokens, tool calls) for the ledger. The model's text is never trusted here: the caller runs
/// the Validator on result.raw.</p>
Class MyOwn.AIHub.Engine Extends MyOwn.Agent.Engine.Base
{

Parameter PROVIDERS = "openai,anthropic,gemini,bedrock";

/// Whether a call can be attempted now; reason is no_key otherwise (provider, model or key missing).
ClassMethod Ready(Output reason As %String) As %Boolean
{
    Set reason = ""
    If ##class(MyOwn.Agent.AIEnv).Mode() = "replay" Quit 1
    Set provider = ##class(MyOwn.Agent.AIEnv).Provider()
    If '$ListFind($ListFromString(..#PROVIDERS), provider) || (##class(MyOwn.Agent.AIEnv).Model() = "") || '##class(MyOwn.Agent.AIEnv).KeyConfigured() {
        Set reason = "no_key"
        Quit 0
    }
    Quit 1
}

ClassMethod Decide(workflow As %String, contextJSON As %String, Output result As %DynamicObject) As %Status
{
    Set mode = ##class(MyOwn.Agent.AIEnv).Mode()
    Set timeout = ##class(MyOwn.Agent.AIEnv).TimeoutSeconds()
    Set result = {"provider": ($Select(mode = "replay": "replay", 1: ##class(MyOwn.Agent.AIEnv).Provider())), "model": ($Select(mode = "replay": "", 1: ##class(MyOwn.Agent.AIEnv).Model())), "latencyMs": 0, "iterations": 0, "toolCalls": []}
    Set result.usage = {"promptTokens": 0, "completionTokens": 0, "totalTokens": 0}
    If '..Ready(.reason) Quit ..Fallback(reason, "provider, model or key not configured")

    Set token = $Increment(^IRIS.Temp.MyOwnAIHub)
    Set input = {"workflow": (workflow), "context": (contextJSON), "mode": (mode), "keyVar": (##class(MyOwn.Agent.AIEnv).KeyVariable()), "timeoutSeconds": (timeout)}
    Set ^IRIS.Temp.MyOwnAIHub(token, "in") = input.%ToJSON()
    Set started = $ZHorolog
    Job ##class(MyOwn.AIHub.Engine).Worker(token)::5
    If '$Test {
        Kill ^IRIS.Temp.MyOwnAIHub(token)
        Quit ..Fallback("provider_error", "the engine worker did not start")
    }
    Set pid = $ZChild
    Set deadline = started + timeout
    While '$Data(^IRIS.Temp.MyOwnAIHub(token, "out")) && ($ZHorolog < deadline) {
        Hang 0.05
    }
    Set result.latencyMs = ..Ms(started)
    If '$Data(^IRIS.Temp.MyOwnAIHub(token, "out")) {
        ; Keep the tool calls made so far (they show where the time went), then remove "in",
        ; which tells a worker that is still running not to write anything more.
        Set result.toolCalls = ##class(MyOwn.AIHub.Policy.LedgerAudit).Abandoned(token)
        Kill ^IRIS.Temp.MyOwnAIHub(token)
        Try {
            Do $System.Process.Terminate(pid)
        } Catch {
        }
        Quit ..Fallback("provider_timeout", "no answer within " _ timeout _ " s")
    }
    Set out = {}.%FromJSON(^IRIS.Temp.MyOwnAIHub(token, "out"))
    Kill ^IRIS.Temp.MyOwnAIHub(token)
    Set answer = out.%Get("result")
    If $IsObject(answer) {
        Set iterator = answer.%GetIterator()
        While iterator.%GetNext(.key, .value) {
            If key '= "latencyMs" Do result.%Set(key, value)
        }
    }
    If out.%Get("reason") '= "" Quit ..Fallback(out.reason, out.%Get("error"))
    Quit $$$OK
}

/// Runs one decision in its own job and leaves {result, reason, error} in ^IRIS.Temp.MyOwnAIHub.
ClassMethod Worker(token As %Integer)
{
    Set out = {"result": {}}
    Try {
        Set input = {}.%FromJSON($Get(^IRIS.Temp.MyOwnAIHub(token, "in"), "{}"))
        Set ^||MyOwnAI("mode") = input.%Get("mode")
        Set ^||MyOwnAI("keyVar") = input.%Get("keyVar")
        Do ##class(MyOwn.AIHub.Policy.LedgerAudit).Reset(token)
        If input.%Get("mode") = "replay" {
            Set tSC = ..Replay(input.workflow, input.context, .answer)
        } Else {
            Set tSC = ..Live(input.workflow, input.context, input.timeoutSeconds, .answer)
        }
        If $IsObject($Get(answer)) Set out.result = answer
        If $$$ISERR(tSC) Do ..SetFailure(out, $System.Status.GetErrorText(tSC))
    } Catch exception {
        Do ..SetFailure(out, exception.DisplayString())
    }
    Set out.result.toolCalls = ##class(MyOwn.AIHub.Policy.LedgerAudit).Collected()
    If $Data(^IRIS.Temp.MyOwnAIHub(token, "in")) Set ^IRIS.Temp.MyOwnAIHub(token, "out") = out.%ToJSON()
}

/// One real call: provider from the environment, the key only as an @{env:...} placeholder.
ClassMethod Live(workflow As %String, contextJSON As %String, timeoutSeconds As %Integer, Output answer As %DynamicObject) As %Status
{
    Set providerName = ##class(MyOwn.Agent.AIEnv).Provider()
    Set answer = {"provider": (providerName), "model": (##class(MyOwn.Agent.AIEnv).Model()), "iterations": 0}
    Set answer.usage = {"promptTokens": 0, "completionTokens": 0, "totalTokens": 0}
    Set provider = ##class(%AI.Provider).Create(providerName, {"api_key": ("@{env:" _ ##class(MyOwn.Agent.AIEnv).KeyVariable() _ "}")})
    Set agent = ##class(MyOwn.AIHub.Agent).%New(provider)
    Set agent.Model = answer.model
    Set agent.SystemPrompt = ##class(MyOwn.AIHub.Prompt).Instructions(workflow)
    Set tSC = agent.%Init()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..AttachPolicies(agent.ToolManager)
    If $$$ISERR(tSC) Quit tSC
    Set input = ##class(MyOwn.AIHub.Prompt).Input(workflow, contextJSON)
    ; A model that refuses the thinking option is retried once without it, and remembered
    ; (per provider and model, until IRIS restarts) so later calls skip it.
    Set noThinkingKey = providerName _ ":" _ answer.model
    Set noThinking = +$Get(^IRIS.Temp.MyOwnAIHub("noThinking", noThinkingKey))
    Set config = ..SessionConfig(providerName, timeoutSeconds, noThinking)
    Try {
        Set session = agent.CreateSession(config)
        Set response = agent.Chat(session, input)
    } Catch exception {
        If '..ThinkingRejected(exception.DisplayString(), config) Throw exception
        Set ^IRIS.Temp.MyOwnAIHub("noThinking", noThinkingKey) = 1
        Set answer.notice = "thinking_rejected: the provider refused reasoning_effort; retried without it"
        Set session = agent.CreateSession(..SessionConfig(providerName, timeoutSeconds, 1))
        Set response = agent.Chat(session, input)
    }
    If noThinking Set answer.notice = "thinking_skipped: this model refused reasoning_effort earlier"
    Set stats = session.GetStats()
    Set answer.iterations = +stats.%Get("total_interactions")
    Set usage = response.Usage
    Set promptTokens = +stats.%Get("total_prompt_tokens")
    Set completionTokens = +stats.%Get("total_completion_tokens")
    ; total_tokens as reported includes hidden reasoning that is not broken out (T03).
    Set totalTokens = promptTokens + completionTokens + stats.%Get("total_reasoning_tokens")
    If $IsObject(usage) && (+usage.%Get("total_tokens") > totalTokens) Set totalTokens = +usage.%Get("total_tokens")
    Set answer.usage = {"promptTokens": (promptTokens), "completionTokens": (completionTokens), "totalTokens": (totalTokens)}
    Set raw = response.Content
    If $IsObject(raw) Set raw = ""
    Set answer.raw = raw
    If $IsObject(response.Extra) Set answer.finishReason = response.Extra.%Get("finish_reason")
    Quit $$$OK
}

/// Recorded answers: same tool manager and policies as live, no provider.
ClassMethod Replay(workflow As %String, contextJSON As %String, Output answer As %DynamicObject) As %Status
{
    Set context = {}.%FromJSON(contextJSON)
    Set case = ##class(MyOwn.AIHub.Fixtures).Pick(workflow, context)
    Set tSC = ##class(MyOwn.AIHub.Fixtures).Get(case, .fixture)
    If $$$ISERR(tSC) Quit tSC
    Set answer = {"provider": "replay", "model": ("replay:" _ fixture.%Get("source")), "replayCase": (case), "iterations": 1, "usage": (fixture.usage)}
    Set tools = fixture.%Get("tools")
    If $IsObject(tools) && (tools.%Size() > 0) {
        Set answer.iterations = 2
        Set manager = ##class(%AI.ToolMgr).%New()
        Set tSC = manager.RegisterToolSet("MyOwn.AIHub.ToolSet.Ops")
        If $$$ISERR(tSC) Quit tSC
        ; The write tool exists only in the test package; registering it shows the policy, not the ToolSet, stops it.
        If case = "write-tool" {
            Set tSC = manager.AddTool("iris:MyOwn.AIHub.Test.WriteTool")
            If $$$ISERR(tSC) Quit tSC
        }
        Set tSC = ..AttachPolicies(manager)
        If $$$ISERR(tSC) Quit tSC
        For index = 0:1:(tools.%Size() - 1) {
            Set call = tools.%Get(index)
            Set arguments = {}.%FromJSON(##class(MyOwn.AIHub.Fixtures).Fill(call.args.%ToJSON(), context))
            If arguments.%Get("taskId") ? 1.N Do arguments.%Set("taskId", +arguments.taskId, "number")
            Try {
                Do manager.ExecuteTool(call.name, arguments)
            } Catch exception {
                ; A denied or failed tool is recorded by the audit policy; the run goes on, as in live.
            }
        }
    }
    If case = "timeout" Hang fixture.latencyMs / 1000
    Set error = fixture.%Get("error")
    If $IsObject(error) Quit ..Fallback(error.reason, error.detail)
    Set answer.raw = ##class(MyOwn.AIHub.Fixtures).Fill(fixture.%Get("raw"), context)
    Quit $$$OK
}

/// The read-only allow-list and the audit collector, as global policies of the tool manager.
ClassMethod AttachPolicies(manager As %AI.ToolMgr) As %Status
{
    Set tSC = manager.SetAuthPolicy(##class(MyOwn.AIHub.Policy.ReadOnlyAuth).%New())
    If $$$ISERR(tSC) Quit tSC
    Quit manager.SetAuditPolicy(##class(MyOwn.AIHub.Policy.LedgerAudit).%New())
}

/// Short loop, small output, low reasoning effort. extra_params is merged into the top level of
/// the provider request; Gemini refused a top-level generationConfig there (T04), so the effort
/// goes as reasoning_effort, and a refusal of it is retried once without it. OpenAI gets JSON mode.
ClassMethod SessionConfig(providerName As %String, timeoutSeconds As %Integer, noThinking As %Boolean = 0) As %DynamicObject
{
    Set maxTokens = ##class(MyOwn.Agent.AIEnv).MaxOutputTokens()
    Set config = {"max_iterations": 2, "timeout_ms": (timeoutSeconds * 1000), "max_tokens": (maxTokens), "temperature": 0}
    Set thinking = ##class(MyOwn.Agent.AIEnv).Thinking()
    If (providerName = "gemini") && (thinking '= "default") && 'noThinking {
        Set config."extra_params" = {"reasoning_effort": (thinking)}
    } ElseIf providerName = "openai" {
        Set config."response_format" = {"type": "json_object"}
    }
    Quit config
}

/// Whether a provider error is a refusal of the reasoning option we sent (public for tests):
/// only when we sent one, and the provider rejected the request as invalid.
ClassMethod ThinkingRejected(text As %String, config As %DynamicObject) As %Boolean
{
    If '$IsObject(config) || '$IsObject(config.%Get("extra_params")) Quit 0
    If config."extra_params".%Get("reasoning_effort") = "" Quit 0
    Set text = $ZConvert(text, "L")
    If (text '[ "invalid") && (text '[ "unknown") && (text '[ "not supported") && (text '[ "unsupported") Quit 0
    Quit (text [ "reasoning") || (text [ "thinking") || (text [ "unknown name") || (text [ "extra")
}

ClassMethod SetFailure(out As %DynamicObject, text As %String) [ Private ]
{
    Set reason = "provider_error"
    If text [ "AIHUB_FALLBACK:" {
        Set reason = $Piece($Piece(text, "AIHUB_FALLBACK:", 2), ":", 1)
        Set text = $Piece($Piece(text, "AIHUB_FALLBACK:", 2), ":", 2, 999)
    }
    Set out.reason = reason
    Set out.error = ..Redact(text)
}

ClassMethod Fallback(reason As %String, detail As %String) As %Status [ Private ]
{
    Quit $$$ERROR($$$GeneralError, "AIHUB_FALLBACK:" _ reason _ ":" _ ..Redact(detail))
}

/// Provider errors never carry the key, but the text is cut and scrubbed before it is stored.
ClassMethod Redact(text As %String) As %String [ Private ]
{
    Set key = $System.Util.GetEnviron(##class(MyOwn.Agent.AIEnv).KeyVariable())
    If $Length(key) >= 8 Set text = $Replace(text, key, "[redacted]")
    Quit $Extract($Translate(text, $Char(10, 13), "  "), 1, 300)
}

ClassMethod Ms(started) As %Integer [ Private ]
{
    Set elapsed = $ZHorolog - started
    If elapsed < 0 Set elapsed = elapsed + 86400
    Quit elapsed * 1000 \ 1
}

}
