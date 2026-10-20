/// Removes old agent event and observability records without touching decisions or proposals.
Class MyOwn.Task.AgentRetention Extends %SYS.Task.Definition
{

Parameter TaskName = "MyOwn Agent retention";

/// Number of days for which transient agent telemetry is retained.
Property RetentionDays As %Integer(MINVAL = 1, MAXVAL = 3650) [ InitialExpression = 30 ];

Method OnTask() As %Status
{
    Set cutoff = $ZDateTime($Horolog - ..RetentionDays, 3, 1)
    Set tSC = ..DeleteOlder("MyOwn_Agent.ToolCall", "At", "MyOwn.Agent.ToolCall", cutoff, .toolCallsDeleted)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..DeleteOlder("MyOwn_Agent.Ledger", "StartedAt", "MyOwn.Agent.Ledger", cutoff, .ledgerDeleted)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..DeleteOlder("MyOwn_Agent.Event", "ReceivedAt", "MyOwn.Agent.Event", cutoff, .eventsDeleted)
    Quit tSC
}

Method DeleteOlder(table As %String, timestampColumn As %String, className As %String, cutoff As %TimeStamp, Output deleted As %Integer) As %Status [ Private ]
{
    Set deleted = 0
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT ID FROM " _ table _ " WHERE """ _ timestampColumn _ """ < ?")
    If $$$ISERR(tSC) Quit tSC
    Set result = statement.%Execute(cutoff)
    If result.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, result.%Message)
    Set count = 0
    While result.%Next() {
        Set count = count + 1
        Set ids(count) = result.%Get("ID")
    }
    For index = 1:1:count {
        Set tSC = $ClassMethod(className, "%DeleteId", ids(index))
        If $$$ISERR(tSC) Quit
        Set deleted = deleted + 1
    }
    Quit tSC
}

}
