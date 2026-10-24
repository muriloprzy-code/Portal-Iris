/// Single source of the AI provider configuration: environment variables only
/// (MYOWN_AI_PROVIDER, MYOWN_AI_MODEL, MYOWN_AI_API_KEY, MYOWN_AI_MODE, MYOWN_AI_TIMEOUT_SECONDS,
/// MYOWN_AI_MAX_OUTPUT_TOKENS, MYOWN_AI_THINKING). The portal configuration only reads these values and never
/// exposes the key: it reports whether one is configured.
/// <p>Tests may override the mode, the key variable and the timeout for the current process only
/// through ^||MyOwnAI("mode"), ^||MyOwnAI("keyVar") and ^||MyOwnAI("timeout"); nothing else
/// changes these values.</p>
Class MyOwn.Agent.AIEnv
{

Parameter DEFAULTTIMEOUTSECONDS = 20;

Parameter DEFAULTMAXOUTPUTTOKENS = 400;

ClassMethod Provider() As %String
{
    Quit $ZConvert(..Value("MYOWN_AI_PROVIDER"), "L")
}

ClassMethod Model() As %String
{
    Quit ..Value("MYOWN_AI_MODEL")
}

/// live (default) or replay (recorded responses, no key and no network).
ClassMethod Mode() As %String
{
    Set mode = $ZConvert($Get(^||MyOwnAI("mode"), ..Value("MYOWN_AI_MODE")), "L")
    Quit $Select(mode = "replay": "replay", 1: "live")
}

/// Name of the environment variable that holds the key (for @{env:...} placeholders).
ClassMethod KeyVariable() As %String
{
    Quit $Get(^||MyOwnAI("keyVar"), "MYOWN_AI_API_KEY")
}

ClassMethod KeyConfigured() As %Boolean
{
    Quit (..Value(..KeyVariable()) '= "")
}

/// Deadline of one provider call, in seconds (5 to 55, below the 60 s web gateway limit).
ClassMethod TimeoutSeconds() As %Integer
{
    Quit ..Bounded($Get(^||MyOwnAI("timeout"), ..Value("MYOWN_AI_TIMEOUT_SECONDS")), ..#DEFAULTTIMEOUTSECONDS, 5, 55)
}

ClassMethod MaxOutputTokens() As %Integer
{
    Quit ..Bounded(..Value("MYOWN_AI_MAX_OUTPUT_TOKENS"), ..#DEFAULTMAXOUTPUTTOKENS, 64, 4000)
}

/// Reasoning effort asked of the model: low (default), high, or default (send nothing).
ClassMethod Thinking() As %String
{
    Set value = $ZConvert(..Value("MYOWN_AI_THINKING"), "L")
    Quit $Select((value = "high") || (value = "default"): value, 1: "low")
}

/// What the portal may show: never the key itself.
ClassMethod PublicView() As %DynamicObject
{
    Set data = {}
    Set data.provider = ..Provider()
    Set data.model = ..Model()
    Set data.mode = ..Mode()
    Set data.apiKeyConfigured = ..KeyConfigured()
    Set data.timeoutSeconds = ..TimeoutSeconds()
    Set data.maxOutputTokens = ..MaxOutputTokens()
    Set data.thinking = ..Thinking()
    Set data.source = "environment"
    Quit data
}

ClassMethod Value(name As %String) As %String [ Private ]
{
    Quit $ZStrip($System.Util.GetEnviron(name), "<>WC")
}

ClassMethod Bounded(value As %String, default As %Integer, minimum As %Integer, maximum As %Integer) As %Integer [ Private ]
{
    If (value = "") || (value '? 1.N) Quit default
    Quit $Select(+value < minimum: minimum, +value > maximum: maximum, 1: +value)
}

}
