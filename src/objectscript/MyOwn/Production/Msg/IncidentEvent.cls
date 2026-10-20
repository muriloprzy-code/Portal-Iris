Class MyOwn.Production.Msg.IncidentEvent Extends (Ens.Request, %JSON.Adaptor)
{

Property Source As %String(MAXLEN = 20);
Property Fingerprint As %String(MAXLEN = 128);
Property ContextJSON As %String(MAXLEN = 32000);
Property TraceId As %String(MAXLEN = 128);

Storage Default
{
<Data name="IncidentEventDefaultData">
<Subscript>"IncidentEvent"</Subscript>
<Value name="1">
<Value>Source</Value>
</Value>
<Value name="2">
<Value>Fingerprint</Value>
</Value>
<Value name="3">
<Value>ContextJSON</Value>
</Value>
<Value name="4">
<Value>TraceId</Value>
</Value>
</Data>
<DefaultData>IncidentEventDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
