/// A synthetic target of the public demo (task, user or role), seeded by MyOwn.Demo.Seed. In demo
/// mode confirmations act on these records instead of IRIS; StateJSON holds the current state.
Class MyOwn.Demo.Target Extends %Persistent
{

Property Kind As %String(VALUELIST = ",task,user,role") [ Required ];

Property Name As %String(MAXLEN = 160) [ Required ];

/// Synthetic task id (tasks only).
Property TaskId As %Integer;

Property StateJSON As %String(MAXLEN = 2000);

Index KindNameIndex On (Kind, Name) [ Unique ];

Index TaskIdIndex On TaskId;

Storage Default
{
<Data name="TargetDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Kind</Value>
</Value>
<Value name="3">
<Value>Name</Value>
</Value>
<Value name="4">
<Value>TaskId</Value>
</Value>
<Value name="5">
<Value>StateJSON</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Demo.TargetD</DataLocation>
<DefaultData>TargetDefaultData</DefaultData>
<IdLocation>^MyOwn.Demo.TargetD</IdLocation>
<IndexLocation>^MyOwn.Demo.TargetI</IndexLocation>
<StreamLocation>^MyOwn.Demo.TargetS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
