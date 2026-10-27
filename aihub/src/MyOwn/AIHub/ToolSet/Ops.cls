/// The only tools the agent gets: the read-only MyOwn.AIHub.Tools.Ops. The authorization and
/// audit policies are attached to the agent's tool manager as global policies (see
/// MyOwn.AIHub.Engine), so they also cover any tool registered outside this ToolSet.
/// The Exclude is a second barrier behind that allow-list: a tool whose name does not start with
/// "Get" and a capital letter is never listed to the model, even if one is added to Tools.Ops.
/// MyOwn.AIHub.Test.ExcludeToolSet repeats it next to a write tool to prove it (test AH-17).
Class MyOwn.AIHub.ToolSet.Ops Extends %AI.ToolSet [ DependsOn = MyOwn.AIHub.Tools.Ops ]
{

/// The Exclude regex (POSIX, searched in the tool name); tests compare it with the test ToolSet.
Parameter EXCLUDEMATCH = "^(?!Get[A-Z])";

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="MyOwnOpsReadOnly">
  <Description>Read-only task and health tools of the MyOwn portal.</Description>
  <Include Class="MyOwn.AIHub.Tools.Ops"/>
  <Exclude Match="^(?!Get[A-Z])"/>
</ToolSet>
}

}
