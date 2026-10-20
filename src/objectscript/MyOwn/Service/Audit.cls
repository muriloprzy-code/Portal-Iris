Class MyOwn.Service.Audit
{

Parameter Source = "MyOwn";
Parameter Type = "Administration";
Parameter Event = "Change";

/// Native audit events of the agent specification: MyOwn/Agent/&lt;name&gt;.
Parameter AgentType = "Agent";

Parameter AgentEvents = "Decision,ProposalCreated,ProposalConfirmed,ProposalRejected,ProposalExpired,ExecutionResult,ConfigChange,KillSwitch";

/// Records MyOwn/Agent/<var>event</var>. The event data starts with the agent marker
/// <code>agent=1;decisionId=N</code> (agent=0 for human configuration changes) so agent-originated
/// events can be filtered. Only ids, enums and identifiers are written: never secrets or model text.
ClassMethod RecordAgent(event As %String, decisionId As %Integer, target As %String, succeeded As %Boolean, detail As %String = "", agentOriginated As %Boolean = 1) As %Status
{
    Set tSC = ..AgentEventData(event, decisionId, target, succeeded, detail, agentOriginated, .eventData)
    If $$$ISERR(tSC) Quit tSC
    Set recorded = $System.Security.Audit(..#Source, ..#AgentType, event, eventData, "Agent " _ event _ " " _ $Select(succeeded:"Success", 1:"Failure"))
    Quit $Select(recorded:$$$OK, 1:$$$ERROR($$$GeneralError, "AUDIT_EVENT_DISABLED"))
}

/// Builds the event data of an agent audit event (no side effects, so it can be tested).
ClassMethod AgentEventData(event As %String, decisionId As %Integer, target As %String, succeeded As %Boolean, detail As %String, agentOriginated As %Boolean, Output eventData As %String) As %Status
{
    Set eventData = ""
    If '$ListFind($ListFromString(..#AgentEvents), event) Quit $$$ERROR($$$GeneralError, "UNKNOWN_AUDIT_EVENT")
    Set eventData = "agent=" _ (+agentOriginated) _ ";decisionId=" _ (+decisionId) _ ";event=" _ event _ ";target=" _ ..SafeValue(target, 120) _ ";outcome=" _ $Select(succeeded:"Success", 1:"Failure") _ ";actor=" _ ..SafeValue($Username, 60)
    If detail '= "" Set eventData = eventData _ ";detail=" _ ..SafeValue(detail, 120)
    Quit $$$OK
}

/// Records safe metadata for an attempted state-changing operation.
ClassMethod Record(action As %String, target As %String, succeeded As %Boolean) As %Status
{
    Set action = ..SafeValue(action, 40)
    Set target = ..SafeValue(target, 120)
    Set outcome = $Select(succeeded:"Success", 1:"Failure")
    Set eventData = "action=" _ action _ ";target=" _ target _ ";outcome=" _ outcome
    Set description = action _ " " _ outcome
    Quit $System.Security.Audit(..#Source, ..#Type, ..#Event, eventData, description)
}

ClassMethod SafeValue(value As %String, maximum As %Integer) As %String [ Private ]
{
    Set value = $Translate(value, $Char(13, 10, 9), "   ")
    Set value = $Replace(value, ";", "_")
    Set value = $Replace(value, "=", "_")
    Quit $Extract(value, 1, maximum)
}

}
