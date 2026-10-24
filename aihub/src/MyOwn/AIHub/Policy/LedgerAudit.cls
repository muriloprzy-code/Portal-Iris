/// Collects every tool execution and denial of the current engine run in a process-private
/// global. The engine returns them with the result and the portal stores them as
/// MyOwn.Agent.ToolCall rows of the ledger entry (denials also go to the audit log).
Class MyOwn.AIHub.Policy.LedgerAudit Extends %AI.Policy.Audit
{

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject, result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
    Set ok = $$$ISOK(status)
    Set summary = $Select(ok: "ok", 1: $System.Status.GetErrorText(status))
    If ok, $IsObject(result) Set summary = "ok, " _ $Length(result.%Get("result_json")) _ " characters"
    Do ..Add(call, $Select(ok: "ok", 1: "error"), summary, duration)
    Quit $$$OK
}

Method %LogDenial(call As %DynamicObject, metadata As %DynamicObject, status As %Status) As %Status
{
    Do ..Add(call, "denied", $System.Status.GetErrorText(status), 0)
    Quit $$$OK
}

Method Add(call As %DynamicObject, status As %String, summary As %String, duration As %Integer) [ Private ]
{
    Set arguments = ""
    If $IsObject(call) Set arguments = $Select($IsObject(call.%Get("arguments")): call.arguments.%ToJSON(), 1: call.%Get("arguments"))
    Set entry = {"name": ($Select($IsObject(call): call.%Get("name"), 1: "")), "args": ($Extract(arguments, 1, 500)), "summary": ($Extract(summary, 1, 300)), "durationMs": (+duration), "status": (status)}
    ; atMs: time since the engine run started, so the LLM time before each tool call is visible.
    If $Data(^||MyOwnAIHub("start")) {
        Set entry.atMs = ($ZHorolog - ^||MyOwnAIHub("start")) * 1000 \ 1
        Set entry.summary = $Extract(entry.summary _ " (at " _ entry.atMs _ " ms)", 1, 300)
    }
    Set index = $Increment(^||MyOwnAIHub("calls"))
    Set ^||MyOwnAIHub("calls", index) = entry.%ToJSON()
    ; Also where the waiting engine can read it if this run is abandoned at the deadline.
    Set token = $Get(^||MyOwnAIHub("token"))
    If token '= "", $Data(^IRIS.Temp.MyOwnAIHub(token, "in")) Set ^IRIS.Temp.MyOwnAIHub(token, "calls", index) = entry.%ToJSON()
}

/// The calls collected in this process since the last Reset().
ClassMethod Collected() As %DynamicArray
{
    Set calls = []
    For index = 1:1:$Get(^||MyOwnAIHub("calls")) {
        Do calls.%Push({}.%FromJSON(^||MyOwnAIHub("calls", index)))
    }
    Quit calls
}

/// Starts a new run; token links the calls to the waiting engine (see MyOwn.AIHub.Engine).
ClassMethod Reset(token As %String = "")
{
    Kill ^||MyOwnAIHub
    Set ^||MyOwnAIHub("start") = $ZHorolog
    If token '= "" Set ^||MyOwnAIHub("token") = token
}

/// Tool calls a worker recorded for token before it was abandoned.
ClassMethod Abandoned(token As %String) As %DynamicArray
{
    Set calls = []
    Set index = ""
    For {
        Set index = $Order(^IRIS.Temp.MyOwnAIHub(token, "calls", index), 1, json)
        If index = "" Quit
        Do calls.%Push({}.%FromJSON(json))
    }
    Quit calls
}

}
