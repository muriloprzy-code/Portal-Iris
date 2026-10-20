Class MyOwn.Production.Msg.AgentResponse Extends (Ens.Response, %JSON.Adaptor)
{

Property DecisionJSON As %String(MAXLEN = 32000);
Property Engine As %String(MAXLEN = 20);
Property Outcome As %String(MAXLEN = 30);
Property TraceId As %String(MAXLEN = 128);
Property EventId As %Integer;
Property DecisionId As %Integer;
Property ProposalId As %Integer;

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
</Data>
<DefaultData>AgentResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
