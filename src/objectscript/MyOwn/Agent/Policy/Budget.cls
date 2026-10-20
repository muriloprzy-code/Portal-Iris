Class MyOwn.Agent.Policy.Budget
{

ClassMethod Evaluate(config As MyOwn.Agent.Config, requestedTokens As %Integer, Output result As %DynamicObject) As %Status
{
    Set result = {}
    Set result.allowed = 1
    Set result.reason = ""
    Set result.usedToday = 0
    If requestedTokens > config.PerDecisionTokenBudget {
        Set result.allowed = 0
        Set result.reason = "PER_DECISION_BUDGET_EXCEEDED"
        Quit $$$OK
    }
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT COALESCE(SUM(TotalTokens),0) AS UsedToday FROM MyOwn_Agent.Ledger WHERE CAST(StartedAt AS DATE) = CURRENT_DATE")
    If $$$ISERR(tSC) Quit tSC
    Set query = statement.%Execute()
    If query.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, query.%Message)
    If query.%Next() Set result.usedToday = +query.%Get("UsedToday")
    If result.usedToday >= config.DailyTokenBudget {
        Set result.allowed = 0
        Set result.reason = "DAILY_BUDGET_EXCEEDED"
    }
    Quit $$$OK
}

ClassMethod CallsAllowed(config As MyOwn.Agent.Config, Output allowed As %Boolean, Output recentCalls As %Integer) As %Status
{
    Set allowed = 1
    Set recentCalls = 0
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare("SELECT COUNT(*) AS RecentCalls FROM MyOwn_Agent.Ledger WHERE StartedAt >= DATEADD(hour, -1, CURRENT_TIMESTAMP)")
    If $$$ISERR(tSC) Quit tSC
    Set query = statement.%Execute()
    If query.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, query.%Message)
    If query.%Next() Set recentCalls = +query.%Get("RecentCalls")
    Set allowed = (recentCalls < config.MaxAgentCallsPerHour)
    Quit $$$OK
}

}
