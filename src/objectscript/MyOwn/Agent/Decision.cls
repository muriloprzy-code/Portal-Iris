Class MyOwn.Agent.Decision Extends (%Persistent, %JSON.Adaptor)
{

Property EventId As %Integer;
Property Workflow As %String(MAXLEN = 40) [ Required ];
Property Engine As %String(MAXLEN = 20) [ Required ];
Property Action As %String(MAXLEN = 40) [ Required ];
Property Severity As %String(MAXLEN = 20);
Property RiskLevel As %String(MAXLEN = 20);
Property TargetType As %String(MAXLEN = 40);
Property TargetId As %String(MAXLEN = 200);
Property Rationale As %String(MAXLEN = 600);
Property Confidence As %Double;
Property EvidenceJSON As %Stream.GlobalCharacter;
Property RawModelOutput As %String(MAXLEN = 1000);
Property ValidationStatus As %String(MAXLEN = 20) [ InitialExpression = "valid" ];
Property DowngradedBy As %String(MAXLEN = 120);
Property Autonomy As %String(MAXLEN = 20);
Property AppliedAutomatically As %Boolean [ InitialExpression = 0 ];
Property TraceId As %String(MAXLEN = 128) [ Required ];
Property DecidedAt As %TimeStamp [ Required ];

/// Sanitized access-request conditions (JSON array of at most three short strings).
Property ConditionsJSON As %String(MAXLEN = 1000);

/// Deterministic Gate result {allowed, finalAction, downgradedBy, createProposal, reason}.
Property GateJSON As %String(MAXLEN = 2000);

Index EventIndex On EventId;
Index TraceIdIndex On TraceId;
Index DecidedAtIndex On DecidedAt;
Index WorkflowEngineIndex On (Workflow, Engine);

Storage Default
{
<Data name="DecisionDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>EventId</Value>
</Value>
<Value name="3">
<Value>Workflow</Value>
</Value>
<Value name="4">
<Value>Engine</Value>
</Value>
<Value name="5">
<Value>Action</Value>
</Value>
<Value name="6">
<Value>Severity</Value>
</Value>
<Value name="7">
<Value>RiskLevel</Value>
</Value>
<Value name="8">
<Value>TargetType</Value>
</Value>
<Value name="9">
<Value>TargetId</Value>
</Value>
<Value name="10">
<Value>Rationale</Value>
</Value>
<Value name="11">
<Value>Confidence</Value>
</Value>
<Value name="12">
<Value>EvidenceJSON</Value>
</Value>
<Value name="13">
<Value>RawModelOutput</Value>
</Value>
<Value name="14">
<Value>ValidationStatus</Value>
</Value>
<Value name="15">
<Value>DowngradedBy</Value>
</Value>
<Value name="16">
<Value>Autonomy</Value>
</Value>
<Value name="17">
<Value>AppliedAutomatically</Value>
</Value>
<Value name="18">
<Value>TraceId</Value>
</Value>
<Value name="19">
<Value>DecidedAt</Value>
</Value>
<Value name="20">
<Value>ConditionsJSON</Value>
</Value>
<Value name="21">
<Value>GateJSON</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.DecisionD</DataLocation>
<DefaultData>DecisionDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.DecisionD</IdLocation>
<IndexLocation>^MyOwn.Agent.DecisionI</IndexLocation>
<StreamLocation>^MyOwn.Agent.DecisionS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
