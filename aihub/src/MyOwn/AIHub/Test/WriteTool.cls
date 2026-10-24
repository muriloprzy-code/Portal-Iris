/// Test only: a tool with a write intent. It is not in the ToolSet; the replay case "write-tool"
/// registers it next to the ToolSet to prove that MyOwn.AIHub.Policy.ReadOnlyAuth denies it.
/// It changes nothing: if it ever ran, it would only leave a mark the test looks for.
Class MyOwn.AIHub.Test.WriteTool Extends %AI.Tool
{

Parameter REQUIRESAUTH = 1;

/// Suspends a task (test stand-in for a write tool).
ClassMethod SuspendTask(taskId As %Integer(DESCRIPTION="Numeric id of the task")) As %String
{
    Set ^IRIS.Temp.MyOwnAIHubWriteTool = $Get(^IRIS.Temp.MyOwnAIHubWriteTool) + 1
    Quit "suspended"
}

}
