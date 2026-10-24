Include %AI

/// Allow-list authorization: only the read-only tools of MyOwn.AIHub.Tools.Ops may run. Any other
/// tool (a write tool, a built-in, anything registered later) is denied when called, and the
/// denial reaches LedgerAudit.%LogDenial, so every blocked attempt is recorded. The portal agent
/// registers only the read-only ToolSet, so its catalog holds nothing else; a tool hidden by
/// %CanList would fail as "not found" without any audit, which is why listing is not filtered.
Class MyOwn.AIHub.Policy.ReadOnlyAuth Extends %AI.Policy.Authorization
{

Parameter ALLOWED = "GetTaskRuns,GetMetricHistory";

Parameter ORIGIN = "MyOwn.AIHub.Tools.Ops";

Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
{
    If ..IsAllowed(metadata.%Get("origin_class"), call.%Get("name")) Quit $$$OK
    Quit $$$ERROR($$$AICoreToolAccessDenied, "read-only policy: " _ $Extract(call.%Get("name"), 1, 80) _ " is not an allowed tool")
}

/// origin is the class that defines the tool (metadata.origin_class). Public so tests can check
/// the allow-list without a model.
ClassMethod IsAllowed(origin As %String, name As %String) As %Boolean
{
    Quit (origin = ..#ORIGIN) && ($ListFind($ListFromString(..#ALLOWED), name) > 0)
}

}
