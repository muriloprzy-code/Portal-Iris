/// Restores the synthetic demo state every MYOWN_DEMO_RESET_HOURS (scheduled by
/// MyOwn.Demo.Setup only while MYOWN_DEMO_MODE=1). Does nothing outside demo mode.
Class MyOwn.Task.DemoReset Extends %SYS.Task.Definition
{

Parameter TaskName = "MyOwn Demo reset";

Method OnTask() As %Status
{
    If '##class(MyOwn.Demo.Mode).Enabled() Quit $$$OK
    Quit ##class(MyOwn.Demo.Seed).Reset("schedule")
}

}
