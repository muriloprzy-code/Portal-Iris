Class MyOwn.Agent.ToolCall Extends (%Persistent, %JSON.Adaptor)
{

Property LedgerId As %Integer [ Required ];
Property TraceId As %String(MAXLEN = 128) [ Required ];
Property ToolName As %String(MAXLEN = 160) [ Required ];
Property ArgsJSON As %String(MAXLEN = 1000);
Property ResultSummary As %String(MAXLEN = 500);
Property DurationMs As %Integer [ InitialExpression = 0 ];
Property Status As %String(MAXLEN = 20) [ Required ];
Property At As %TimeStamp [ Required ];

Index LedgerIndex On LedgerId;
Index TraceIdIndex On TraceId;
Index AtIndex On At;

Storage Default
{
<Data name="ToolCallDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>LedgerId</Value>
</Value>
<Value name="3">
<Value>TraceId</Value>
</Value>
<Value name="4">
<Value>ToolName</Value>
</Value>
<Value name="5">
<Value>ArgsJSON</Value>
</Value>
<Value name="6">
<Value>ResultSummary</Value>
</Value>
<Value name="7">
<Value>DurationMs</Value>
</Value>
<Value name="8">
<Value>Status</Value>
</Value>
<Value name="9">
<Value>At</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.ToolCallD</DataLocation>
<DefaultData>ToolCallDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.ToolCallD</IdLocation>
<IndexLocation>^MyOwn.Agent.ToolCallI</IndexLocation>
<StreamLocation>^MyOwn.Agent.ToolCallS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
