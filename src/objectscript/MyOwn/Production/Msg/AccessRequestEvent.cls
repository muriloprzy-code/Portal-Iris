Class MyOwn.Production.Msg.AccessRequestEvent Extends (Ens.Request, %JSON.Adaptor)
{

Property RequestId As %Integer;
Property Requester As %String(MAXLEN = 160);
Property RoleRequested As %String(MAXLEN = 160);
Property ContextJSON As %String(MAXLEN = 32000);
Property TraceId As %String(MAXLEN = 128);

Storage Default
{
<Data name="AccessRequestEventDefaultData">
<Subscript>"AccessRequestEvent"</Subscript>
<Value name="1">
<Value>RequestId</Value>
</Value>
<Value name="2">
<Value>Requester</Value>
</Value>
<Value name="3">
<Value>RoleRequested</Value>
</Value>
<Value name="4">
<Value>ContextJSON</Value>
</Value>
<Value name="5">
<Value>TraceId</Value>
</Value>
</Data>
<DefaultData>AccessRequestEventDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
