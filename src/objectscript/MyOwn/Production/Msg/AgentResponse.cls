Class MyOwn.Production.Msg.AgentResponse Extends (Ens.Response, %JSON.Adaptor)
{

Property DecisionJSON As %String(MAXLEN = 32000);
Property Engine As %String(MAXLEN = 20);
Property Outcome As %String(MAXLEN = 30);
Property TraceId As %String(MAXLEN = 128);
Property EventId As %Integer;
Property DecisionId As %Integer;
Property ProposalId As %Integer;

/// valid | rejected (the Validator result for the engine output).
Property ValidationStatus As %String(MAXLEN = 20);

/// Deterministic Gate result {allowed, finalAction, downgradedBy, createProposal}; empty before the Gate step.
Property GateJSON As %String(MAXLEN = 2000);

/// Empty when the AI decided; otherwise why Rules decided (kill_switch, budget, disabled,
/// not_installed, no_key, provider_timeout, provider_error, invalid_json).
Property FallbackReason As %String(MAXLEN = 40);

Storage Default
{
<Data name="AgentResponseDefaultData">
<Subscript>"AgentResponse"</Subscript>
<Value name="1">
<Value>DecisionJSON</Value>
</Value>
<Value name="2">
<Value>Engine</Value>
</Value>
<Value name="3">
<Value>Outcome</Value>
</Value>
<Value name="4">
<Value>TraceId</Value>
</Value>
<Value name="5">
<Value>EventId</Value>
</Value>
<Value name="6">
<Value>DecisionId</Value>
</Value>
<Value name="7">
<Value>ProposalId</Value>
</Value>
<Value name="8">
<Value>ValidationStatus</Value>
</Value>
<Value name="9">
<Value>GateJSON</Value>
</Value>
<Value name="10">
<Value>FallbackReason</Value>
</Value>
</Data>
<DefaultData>AgentResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
