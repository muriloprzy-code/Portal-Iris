Class MyOwn.Agent.Proposal Extends (%Persistent, %JSON.Adaptor)
{

Property DecisionId As %Integer [ Required ];
Property Kind As %String(MAXLEN = 40) [ Required ];
Property TargetType As %String(MAXLEN = 40) [ Required ];
Property TargetId As %String(MAXLEN = 200) [ Required ];
Property BeforeJSON As %Stream.GlobalCharacter;
Property AfterJSON As %Stream.GlobalCharacter;
Property RequiredPrivilege As %String(MAXLEN = 160);
Property UndoHint As %String(MAXLEN = 500);
Property Fingerprint As %String(MAXLEN = 128) [ Required ];
Property State As %String(MAXLEN = 20) [ InitialExpression = "pending" ];
Property CreatedAt As %TimeStamp [ Required ];
Property ExpiresAt As %TimeStamp [ Required ];
Property ResolvedBy As %String(MAXLEN = 160);
Property ResolvedAt As %TimeStamp;
Property ResultMessage As %String(MAXLEN = 500);

Index DecisionIndex On DecisionId;
Index StateIndex On State;
Index ExpiresAtIndex On ExpiresAt;

Method Resolve(newState As %String, resolvedBy As %String, message As %String = "") As %Status
{
    If ..State '= "pending" Quit $$$ERROR($$$GeneralError, "PROPOSAL_ALREADY_RESOLVED")
    If (newState '= "confirmed") && (newState '= "rejected") && (newState '= "executed") && (newState '= "failed") Quit $$$ERROR($$$GeneralError, "PROPOSAL_INVALID_STATE")
    If ..IsExpired() {
        Set ..State = "expired"
        Set ..ResolvedAt = $ZDateTime($Horolog, 3, 1)
        Set ..ResultMessage = "The proposal expired before it was resolved."
        Set tSC = ..%Save()
        If $$$ISERR(tSC) Quit tSC
        Quit $$$ERROR($$$GeneralError, "PROPOSAL_EXPIRED")
    }
    Set ..State = newState
    Set ..ResolvedBy = $Extract(resolvedBy, 1, 160)
    Set ..ResolvedAt = $ZDateTime($Horolog, 3, 1)
    Set ..ResultMessage = $Extract(message, 1, 500)
    Quit ..%Save()
}

/// Marks every pending proposal past ExpiresAt as expired (and audits it), so lists and the
/// Approvals badge never show an expired proposal as pending. Proposals being confirmed or
/// rejected right now (locked) are skipped; ConfirmProposal applies the same rule itself.
ClassMethod ExpireOverdue(Output expired As %Integer) As %Status
{
    Set expired = 0
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT ID FROM MyOwn_Agent.Proposal WHERE State = 'pending' AND ExpiresAt < ?")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute($ZDateTime($Horolog, 3, 1))
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    Set count = 0
    While result.%Next() {
        Set count = count + 1
        Set ids(count) = result.%Get("ID")
    }
    For index = 1:1:count {
        Set id = ids(index)
        Lock +^MyOwn.Agent.Lock("proposal", id):0
        If '$Test Continue
        Try {
            Set proposal = ..%OpenId(id)
            If $IsObject(proposal), proposal.State = "pending", proposal.IsExpired() {
                Set proposal.State = "expired"
                Set proposal.ResolvedAt = $ZDateTime($Horolog, 3, 1)
                Set proposal.ResultMessage = "The proposal expired before confirmation."
                Set tSC = proposal.%Save()
                If $$$ISOK(tSC) Set tSC = ##class(MyOwn.Service.Audit).RecordAgent("ProposalExpired", proposal.DecisionId, "proposal " _ id, 1, "ttl")
                If $$$ISOK(tSC) Set expired = expired + 1
            }
        } Catch exception {
            Set tSC = exception.AsStatus()
        }
        Lock -^MyOwn.Agent.Lock("proposal", id)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method IsExpired() As %Boolean
{
    ; ODBC timestamps must be compared as strings: "<" would compare them as numbers (the year).
    Quit (..ExpiresAt '= "") && ($ZDateTime($Horolog, 3, 1) ] ..ExpiresAt)
}

Storage Default
{
<Data name="ProposalDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>DecisionId</Value>
</Value>
<Value name="3">
<Value>Kind</Value>
</Value>
<Value name="4">
<Value>TargetType</Value>
</Value>
<Value name="5">
<Value>TargetId</Value>
</Value>
<Value name="6">
<Value>BeforeJSON</Value>
</Value>
<Value name="7">
<Value>AfterJSON</Value>
</Value>
<Value name="8">
<Value>RequiredPrivilege</Value>
</Value>
<Value name="9">
<Value>UndoHint</Value>
</Value>
<Value name="10">
<Value>Fingerprint</Value>
</Value>
<Value name="11">
<Value>State</Value>
</Value>
<Value name="12">
<Value>CreatedAt</Value>
</Value>
<Value name="13">
<Value>ExpiresAt</Value>
</Value>
<Value name="14">
<Value>ResolvedBy</Value>
</Value>
<Value name="15">
<Value>ResolvedAt</Value>
</Value>
<Value name="16">
<Value>ResultMessage</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.ProposalD</DataLocation>
<DefaultData>ProposalDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.ProposalD</IdLocation>
<IndexLocation>^MyOwn.Agent.ProposalI</IndexLocation>
<StreamLocation>^MyOwn.Agent.ProposalS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
