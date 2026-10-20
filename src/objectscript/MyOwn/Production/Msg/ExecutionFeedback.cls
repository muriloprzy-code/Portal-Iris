Class MyOwn.Production.Msg.ExecutionFeedback Extends (Ens.Request, %JSON.Adaptor)
{

Property ProposalId As %Integer;
Property State As %String(MAXLEN = 20);
Property Message As %String(MAXLEN = 500);
Property TraceId As %String(MAXLEN = 128);

Storage Default
{
<Data name="ExecutionFeedbackDefaultData">
<Subscript>"ExecutionFeedback"</Subscript>
<Value name="1">
<Value>ProposalId</Value>
</Value>
<Value name="2">
<Value>State</Value>
</Value>
<Value name="3">
<Value>Message</Value>
</Value>
<Value name="4">
<Value>TraceId</Value>
</Value>
</Data>
<DefaultData>ExecutionFeedbackDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
