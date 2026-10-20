Class MyOwn.Agent.Ledger Extends (%Persistent, %JSON.Adaptor)
{

Property TraceId As %String(MAXLEN = 128) [ Required ];
Property Workflow As %String(MAXLEN = 40) [ Required ];
Property Engine As %String(MAXLEN = 20) [ Required ];
Property Provider As %String(MAXLEN = 80);
Property Model As %String(MAXLEN = 160);
Property StartedAt As %TimeStamp [ Required ];
Property DurationMs As %Integer [ InitialExpression = 0 ];
Property PromptTokens As %Integer [ InitialExpression = 0 ];
Property CompletionTokens As %Integer [ InitialExpression = 0 ];
Property TotalTokens As %Integer [ InitialExpression = 0 ];
Property ToolCallCount As %Integer [ InitialExpression = 0 ];
Property Iterations As %Integer [ InitialExpression = 0 ];
Property CostEstimateUSD As %Double;
Property Outcome As %String(MAXLEN = 30) [ Required ];
Property ErrorSummary As %String(MAXLEN = 500);
Property SessionHeaderId As %String(MAXLEN = 128);

Index TraceIdIndex On TraceId;
Index StartedAtIndex On StartedAt;
Index WorkflowEngineIndex On (Workflow, Engine);

Storage Default
{
<Data name="LedgerDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TraceId</Value>
</Value>
<Value name="3">
<Value>Workflow</Value>
</Value>
<Value name="4">
<Value>Engine</Value>
</Value>
<Value name="5">
<Value>Provider</Value>
</Value>
<Value name="6">
<Value>Model</Value>
</Value>
<Value name="7">
<Value>StartedAt</Value>
</Value>
<Value name="8">
<Value>DurationMs</Value>
</Value>
<Value name="9">
<Value>PromptTokens</Value>
</Value>
<Value name="10">
<Value>CompletionTokens</Value>
</Value>
<Value name="11">
<Value>TotalTokens</Value>
</Value>
<Value name="12">
<Value>ToolCallCount</Value>
</Value>
<Value name="13">
<Value>Iterations</Value>
</Value>
<Value name="14">
<Value>CostEstimateUSD</Value>
</Value>
<Value name="15">
<Value>Outcome</Value>
</Value>
<Value name="16">
<Value>ErrorSummary</Value>
</Value>
<Value name="17">
<Value>SessionHeaderId</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.LedgerD</DataLocation>
<DefaultData>LedgerDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.LedgerD</IdLocation>
<IndexLocation>^MyOwn.Agent.LedgerI</IndexLocation>
<StreamLocation>^MyOwn.Agent.LedgerS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
