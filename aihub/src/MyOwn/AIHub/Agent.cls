/// The portal agent: the read-only ToolSet and a short agentic loop. Provider, model and system
/// prompt are set by MyOwn.AIHub.Engine for each decision.
Class MyOwn.AIHub.Agent Extends %AI.Agent
{

Parameter TOOLSETS = "MyOwn.AIHub.ToolSet.Ops";

/// One answer, or one tool round and an answer.
Property MaxIterations As %Integer [ InitialExpression = 2 ];

Property Temperature As %Float [ InitialExpression = 0 ];

}
