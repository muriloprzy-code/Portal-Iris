/// The only tools the agent gets: the read-only MyOwn.AIHub.Tools.Ops. The authorization and
/// audit policies are attached to the agent's tool manager as global policies (see
/// MyOwn.AIHub.Engine), so they also cover any tool registered outside this ToolSet.
Class MyOwn.AIHub.ToolSet.Ops Extends %AI.ToolSet [ DependsOn = MyOwn.AIHub.Tools.Ops ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="MyOwnOpsReadOnly">
  <Description>Read-only task and health tools of the MyOwn portal.</Description>
  <Include Class="MyOwn.AIHub.Tools.Ops"/>
</ToolSet>
}

}
