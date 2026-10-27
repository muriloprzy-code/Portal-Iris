/// Test only: a task that always fails, used by MyOwn.Test.Adapter for the TaskWatcher end-to-end check.
Class MyOwn.Test.FailingTask Extends %SYS.Task.Definition
{

Parameter TaskName = "MyOwn Test failing task";

Method OnTask() As %Status
{
    Quit $$$ERROR($$$GeneralError, "MyOwn adapter test: this task always fails")
}

}
