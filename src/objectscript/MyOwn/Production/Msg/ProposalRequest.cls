Class MyOwn.Production.Msg.ProposalRequest Extends (Ens.Request, %JSON.Adaptor)
{

Property DecisionId As %Integer;
Property DecisionJSON As %String(MAXLEN = 32000);
Property ContextJSON As %String(MAXLEN = 32000);
Property TraceId As %String(MAXLEN = 128);

Storage Default
{
<Data name="ProposalRequestDefaultData">
<Subscript>"ProposalRequest"</Subscript>
<Value name="1">
<Value>DecisionId</Value>
</Value>
<Value name="2">
<Value>DecisionJSON</Value>
</Value>
<Value name="3">
<Value>ContextJSON</Value>
</Value>
<Value name="4">
<Value>TraceId</Value>
</Value>
</Data>
<DefaultData>ProposalRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
