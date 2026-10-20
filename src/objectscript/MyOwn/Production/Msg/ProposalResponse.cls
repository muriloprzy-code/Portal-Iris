Class MyOwn.Production.Msg.ProposalResponse Extends (Ens.Response, %JSON.Adaptor)
{

Property ProposalId As %Integer;

Storage Default
{
<Data name="ProposalResponseDefaultData">
<Subscript>"ProposalResponse"</Subscript>
<Value name="1">
<Value>ProposalId</Value>
</Value>
</Data>
<DefaultData>ProposalResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
