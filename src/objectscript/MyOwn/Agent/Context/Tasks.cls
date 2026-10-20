Class MyOwn.Agent.Context.Tasks
{

ClassMethod GetTask(taskId As %Integer, authorization As %String, Output data As %DynamicObject) As %Status
{
    Set tSC = ##class(MyOwn.Service.Tasks).GetTask(taskId, authorization, .data, .source)
    If $$$ISERR(tSC) Quit tSC
    Set data.integrationSource = source
    Quit $$$OK
}

ClassMethod Candidate(task As %DynamicObject) As %DynamicObject
{
    Set candidate = {}
    Set candidate.id = task.%Get("id")
    Set candidate.type = "task"
    Set candidate.manageable = task.%Get("manageable")
    Quit candidate
}

}
