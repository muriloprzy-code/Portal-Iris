Class MyOwn.Agent.Engine.Base Extends %RegisteredObject [ Abstract ]
{

/// Produce a decision for one supported workflow.
ClassMethod Decide(workflow As %String, contextJSON As %String, Output result As %DynamicObject) As %Status [ Abstract ]
{
}

}
