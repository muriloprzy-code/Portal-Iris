/// Test only: the portal ToolSet's Exclude next to a write tool. It includes the read-only tools
/// and MyOwn.AIHub.Test.WriteTool, then applies the same Exclude as MyOwn.AIHub.ToolSet.Ops, so
/// test AH-15 can show the write tool is neither listed nor runnable. Never given to the agent.
Class MyOwn.AIHub.Test.ExcludeToolSet Extends %AI.ToolSet [ DependsOn = (MyOwn.AIHub.Tools.Ops, MyOwn.AIHub.Test.WriteTool) ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="MyOwnExcludeProbe">
  <Description>Test: read-only tools plus a write tool, behind the portal Exclude.</Description>
  <Include Class="MyOwn.AIHub.Tools.Ops"/>
  <Include Class="MyOwn.AIHub.Test.WriteTool"/>
  <Exclude Match="^(?!Get[A-Z])"/>
</ToolSet>
}

}
