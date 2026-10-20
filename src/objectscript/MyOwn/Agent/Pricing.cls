Class MyOwn.Agent.Pricing Extends (%Persistent, %JSON.Adaptor)
{

Property Model As %String(MAXLEN = 160) [ Required ];
Property InputPer1MTokensUSD As %Double [ InitialExpression = 0 ];
Property OutputPer1MTokensUSD As %Double [ InitialExpression = 0 ];
Property UpdatedAt As %TimeStamp [ Required ];

Index ModelIndex On Model [ Unique ];

ClassMethod Estimate(model As %String, promptTokens As %Integer, completionTokens As %Integer, Output cost As %Double, Output hasPrice As %Boolean) As %Status
{
    Set cost = 0
    Set hasPrice = 0
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT InputPer1MTokensUSD, OutputPer1MTokensUSD FROM MyOwn_Agent.Pricing WHERE Model = ?")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(model)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    If result.%Next() {
        Set hasPrice = 1
        Set cost = ((promptTokens * result.%Get("InputPer1MTokensUSD")) + (completionTokens * result.%Get("OutputPer1MTokensUSD"))) / 1000000
    }
    Quit $$$OK
}

Storage Default
{
<Data name="PricingDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Model</Value>
</Value>
<Value name="3">
<Value>InputPer1MTokensUSD</Value>
</Value>
<Value name="4">
<Value>OutputPer1MTokensUSD</Value>
</Value>
<Value name="5">
<Value>UpdatedAt</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.PricingD</DataLocation>
<DefaultData>PricingDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.PricingD</IdLocation>
<IndexLocation>^MyOwn.Agent.PricingI</IndexLocation>
<StreamLocation>^MyOwn.Agent.PricingS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
