Class MyOwn.Production.Msg.AgentRequest Extends (Ens.Request, %JSON.Adaptor)
{

Property Workflow As %String(MAXLEN = 40);
Property Source As %String(MAXLEN = 20);
Property ContextJSON As %String(MAXLEN = 32000);
Property TraceId As %String(MAXLEN = 128);
Property Actor As %String(MAXLEN = 160);

Storage Default
{
<Data name="AgentRequestDefaultData">
<Subscript>"AgentRequest"</Subscript>
<Value name="1">
<Value>Workflow</Value>
</Value>
<Value name="2">
<Value>Source</Value>
</Value>
<Value name="3">
<Value>ContextJSON</Value>
</Value>
<Value name="4">
<Value>TraceId</Value>
</Value>
<Value name="5">
<Value>Actor</Value>
</Value>
</Data>
<DefaultData>AgentRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
