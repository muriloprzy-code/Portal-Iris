Class MyOwn.Agent.AccessRequest Extends (%Persistent, %JSON.Adaptor)
{

Property Requester As %String(MAXLEN = 160) [ Required ];
Property RoleRequested As %String(MAXLEN = 160) [ Required ];
Property Justification As %String(MAXLEN = 500) [ Required ];
Property Status As %String(MAXLEN = 20) [ InitialExpression = "new" ];
Property DecisionId As %Integer;
Property CreatedAt As %TimeStamp [ Required ];

Index RequesterIndex On Requester;
Index StatusIndex On Status;
Index CreatedAtIndex On CreatedAt;

Storage Default
{
<Data name="AccessRequestDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Requester</Value>
</Value>
<Value name="3">
<Value>RoleRequested</Value>
</Value>
<Value name="4">
<Value>Justification</Value>
</Value>
<Value name="5">
<Value>Status</Value>
</Value>
<Value name="6">
<Value>DecisionId</Value>
</Value>
<Value name="7">
<Value>CreatedAt</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.AccessRequestD</DataLocation>
<DefaultData>AccessRequestDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.AccessRequestD</IdLocation>
<IndexLocation>^MyOwn.Agent.AccessRequestI</IndexLocation>
<StreamLocation>^MyOwn.Agent.AccessRequestS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
