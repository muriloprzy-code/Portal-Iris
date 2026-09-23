Class MeuPortal.HealthPattern Extends %Persistent
{

/// Stable identifier used by the health report.
Property Code As %String(MAXLEN = 40) [ Required ];

Property Title As %String(MAXLEN = 100) [ Required ];

Property Severity As %String(MAXLEN = 20) [ Required ];

Property Recommendation As %String(MAXLEN = 500) [ Required ];

/// Six normalized dimensions: disk, database, locks, alerts, processes, and healthy reserve.
Property MetricVector As %Vector(DATATYPE = "DOUBLE", LEN = 6) [ Required ];

Index CodeIndex On Code [ Unique ];

Storage Default
{
<Data name="HealthPatternDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Code</Value>
</Value>
<Value name="3">
<Value>Title</Value>
</Value>
<Value name="4">
<Value>Severity</Value>
</Value>
<Value name="5">
<Value>Recommendation</Value>
</Value>
<Value name="6">
<Value>MetricVector</Value>
</Value>
</Data>
<DataLocation>^MeuPortal.HealthPatternD</DataLocation>
<DefaultData>HealthPatternDefaultData</DefaultData>
<IdLocation>^MeuPortal.HealthPatternD</IdLocation>
<IndexLocation>^MeuPortal.HealthPatternI</IndexLocation>
<StreamLocation>^MeuPortal.HealthPatternS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
