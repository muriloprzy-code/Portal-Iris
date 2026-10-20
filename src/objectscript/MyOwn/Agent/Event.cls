Class MyOwn.Agent.Event Extends (%Persistent, %JSON.Adaptor)
{

Property Workflow As %String(MAXLEN = 40) [ Required ];
Property Source As %String(MAXLEN = 20) [ Required ];
Property Fingerprint As %String(MAXLEN = 128) [ Required ];
Property PayloadJSON As %Stream.GlobalCharacter;
Property ReceivedAt As %TimeStamp [ Required ];
Property TraceId As %String(MAXLEN = 128) [ Required ];
Property Status As %String(MAXLEN = 20) [ InitialExpression = "new" ];

Index FingerprintIndex On Fingerprint;
Index TraceIdIndex On TraceId;
Index ReceivedAtIndex On ReceivedAt;

Storage Default
{
<Data name="EventDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Workflow</Value>
</Value>
<Value name="3">
<Value>Source</Value>
</Value>
<Value name="4">
<Value>Fingerprint</Value>
</Value>
<Value name="5">
<Value>PayloadJSON</Value>
</Value>
<Value name="6">
<Value>ReceivedAt</Value>
</Value>
<Value name="7">
<Value>TraceId</Value>
</Value>
<Value name="8">
<Value>Status</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.EventD</DataLocation>
<DefaultData>EventDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.EventD</IdLocation>
<IndexLocation>^MyOwn.Agent.EventI</IndexLocation>
<StreamLocation>^MyOwn.Agent.EventS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
