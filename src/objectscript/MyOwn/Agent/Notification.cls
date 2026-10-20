Class MyOwn.Agent.Notification Extends (%Persistent, %JSON.Adaptor)
{

Property Kind As %String(MAXLEN = 40) [ Required ];
Property Severity As %String(MAXLEN = 20) [ Required ];
Property Message As %String(MAXLEN = 1000) [ Required ];
Property RefType As %String(MAXLEN = 40);
Property RefId As %String(MAXLEN = 160);
Property CreatedAt As %TimeStamp [ Required ];
Property DeliveredVia As %String(MAXLEN = 20) [ InitialExpression = "store" ];

Index CreatedAtIndex On CreatedAt;
Index SeverityIndex On Severity;

Storage Default
{
<Data name="NotificationDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Kind</Value>
</Value>
<Value name="3">
<Value>Severity</Value>
</Value>
<Value name="4">
<Value>Message</Value>
</Value>
<Value name="5">
<Value>RefType</Value>
</Value>
<Value name="6">
<Value>RefId</Value>
</Value>
<Value name="7">
<Value>CreatedAt</Value>
</Value>
<Value name="8">
<Value>DeliveredVia</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.NotificationD</DataLocation>
<DefaultData>NotificationDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.NotificationD</IdLocation>
<IndexLocation>^MyOwn.Agent.NotificationI</IndexLocation>
<StreamLocation>^MyOwn.Agent.NotificationS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
