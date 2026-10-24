Class MyOwn.Agent.Config Extends (%Persistent, %JSON.Adaptor)
{

Property KillSwitch As %Boolean [ InitialExpression = 0 ];
Property ReadOnly As %Boolean [ InitialExpression = 0 ];
Property EnginePreference As %String(MAXLEN = 20) [ InitialExpression = "auto" ];
/// Deprecated: provider settings come from the environment (MyOwn.Agent.AIEnv). Kept for storage compatibility.
Property Provider As %String(MAXLEN = 80) [ InitialExpression = "openai" ];
Property Model As %String(MAXLEN = 160) [ InitialExpression = "" ];
Property BaseURL As %String(MAXLEN = 500) [ InitialExpression = "" ];
Property AutonomyTriage As %String(MAXLEN = 20) [ InitialExpression = "assist" ];
Property AutonomyAccess As %String(MAXLEN = 20) [ InitialExpression = "assist" ];
Property DailyTokenBudget As %Integer [ InitialExpression = 100000 ];
Property PerDecisionTokenBudget As %Integer [ InitialExpression = 8000 ];
Property CooldownMinutes As %Integer [ InitialExpression = 15 ];
Property MaxAgentCallsPerHour As %Integer [ InitialExpression = 20 ];
Property ProposalTTLMinutes As %Integer [ InitialExpression = 30 ];
Property HighRiskResources As list Of %String;
Property WebhookURL As %String(MAXLEN = 1000) [ InitialExpression = "" ];
Property DemoMode As %Boolean [ InitialExpression = 0 ];

ClassMethod GetOrCreate(Output config As MyOwn.Agent.Config) As %Status
{
    Set tSC = $$$OK
    Try {
        Set config = ..%OpenId(1)
        If '$IsObject(config) {
            Set config = ..%New()
            Do config.HighRiskResources.Insert("%Admin_Secure")
            Do config.HighRiskResources.Insert("%Admin_Manage")
            Do config.HighRiskResources.Insert("%DB_IRISSYS")
            Set tSC = config.%Save()
            $$$ThrowOnError(tSC)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod PublicView(Output data As %DynamicObject) As %Status
{
    Set tSC = ..GetOrCreate(.config)
    If $$$ISERR(tSC) Quit tSC
    Set data = {}
    Set data.killSwitch = config.KillSwitch
    Set data.readOnly = config.ReadOnly
    Set data.enginePreference = config.EnginePreference
    ; Provider settings come only from the environment (MyOwn.Agent.AIEnv); the persisted
    ; Provider/Model/BaseURL properties are no longer used.
    Set ai = ##class(MyOwn.Agent.AIEnv).PublicView()
    Set data.provider = ai.provider
    Set data.model = ai.model
    Set data.aiMode = ai.mode
    Set data.aiTimeoutSeconds = ai.timeoutSeconds
    Set data.aiThinking = ai.thinking
    Set data.aiMaxOutputTokens = ai.maxOutputTokens
    Set data.aiConfigSource = ai.source
    Set data.aiHubInstalled = ##class(%Dictionary.CompiledClass).%ExistsId("MyOwn.AIHub.Engine")
    Set data.autonomyTriage = config.AutonomyTriage
    Set data.autonomyAccess = config.AutonomyAccess
    Set data.dailyTokenBudget = config.DailyTokenBudget
    Set data.perDecisionTokenBudget = config.PerDecisionTokenBudget
    Set data.cooldownMinutes = config.CooldownMinutes
    Set data.maxAgentCallsPerHour = config.MaxAgentCallsPerHour
    Set data.proposalTTLMinutes = config.ProposalTTLMinutes
    Set data.webhookURL = config.WebhookURL
    Set data.demoMode = config.DemoMode
    Set data.apiKeyConfigured = ai.apiKeyConfigured
    Set data.highRiskResources = []
    For index = 1:1:config.HighRiskResources.Count() {
        Do data.highRiskResources.%Push(config.HighRiskResources.GetAt(index))
    }
    Quit $$$OK
}

ClassMethod ValidateChoice(value As %String, choices As %String) As %Boolean
{
    Quit $ListFind($ListFromString(choices, ","), value) > 0
}

Storage Default
{
<Data name="ConfigDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>KillSwitch</Value>
</Value>
<Value name="3">
<Value>ReadOnly</Value>
</Value>
<Value name="4">
<Value>EnginePreference</Value>
</Value>
<Value name="5">
<Value>Provider</Value>
</Value>
<Value name="6">
<Value>Model</Value>
</Value>
<Value name="7">
<Value>BaseURL</Value>
</Value>
<Value name="8">
<Value>AutonomyTriage</Value>
</Value>
<Value name="9">
<Value>AutonomyAccess</Value>
</Value>
<Value name="10">
<Value>DailyTokenBudget</Value>
</Value>
<Value name="11">
<Value>PerDecisionTokenBudget</Value>
</Value>
<Value name="12">
<Value>CooldownMinutes</Value>
</Value>
<Value name="13">
<Value>MaxAgentCallsPerHour</Value>
</Value>
<Value name="14">
<Value>ProposalTTLMinutes</Value>
</Value>
<Value name="15">
<Value>HighRiskResources</Value>
</Value>
<Value name="16">
<Value>WebhookURL</Value>
</Value>
<Value name="17">
<Value>DemoMode</Value>
</Value>
</Data>
<DataLocation>^MyOwn.Agent.ConfigD</DataLocation>
<DefaultData>ConfigDefaultData</DefaultData>
<IdLocation>^MyOwn.Agent.ConfigD</IdLocation>
<IndexLocation>^MyOwn.Agent.ConfigI</IndexLocation>
<StreamLocation>^MyOwn.Agent.ConfigS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
