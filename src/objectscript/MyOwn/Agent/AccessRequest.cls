Class MyOwn.Agent.AccessRequest Extends (%Persistent, %JSON.Adaptor)
{

Property Requester As %String(MAXLEN = 160) [ Required ];
Property RoleRequested As %String(MAXLEN = 160) [ Required ];
Property Justification As %String(MAXLEN = 500) [ Required ];
Property Status As %String(MAXLEN = 20) [ InitialExpression = "new" ];
Property DecisionId As %Integer;
Property CreatedAt As %TimeStamp [ Required ];

/// Trace of the asynchronous production run that decides this request.
Property TraceId As %String(MAXLEN = 128);

Property ProposalId As %Integer;

Property Engine As %String(MAXLEN = 20);

Property Outcome As %String(MAXLEN = 30);

Property DecidedAt As %TimeStamp;

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
<Value name="8">
<Value>TraceId</Value>
</Value>
<Value name="9">
<Value>ProposalId</Value>
</Value>
<Value name="10">
<Value>Engine</Value>
</Value>
<Value name="11">
<Value>Outcome</Value>
</Value>
<Value name="12">
<Value>DecidedAt</Value>
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
