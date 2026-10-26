/// Applies the demo settings of the environment at every container start (docker/start-iris.sh
/// runs docker/demo-start.script after IRIS is up). With MYOWN_DEMO_MODE=1 it seeds the synthetic
/// targets, creates or updates the "demo" account (role MyOwnDemo, password only from
/// MYOWN_DEMO_USER_PASSWORD) and schedules the reset task; otherwise it disables that account
/// and removes the reset task. The password is never stored by the portal or written to a log.
Class MyOwn.Demo.Setup
{

Parameter DemoUser = "demo";

/// Same values as MyOwn.Demo.Mode (DemoRole) and MyOwn.Task.DemoReset (TaskName), as literals:
/// the methods below run in %SYS, where MyOwn classes are not visible.
Parameter DemoRole = "MyOwnDemo";

Parameter ResetTaskName = "MyOwn Demo reset";

ClassMethod Apply(namespace As %String = {$Namespace}) As %Status
{
    Set tSC = $$$OK
    Try {
        New $Namespace
        Set $Namespace = namespace
        Set enabled = ##class(MyOwn.Demo.Mode).Enabled()
        If enabled {
            $$$ThrowOnError(##class(MyOwn.Demo.Seed).EnsureSeeded())
        }
        Set hours = ##class(MyOwn.Demo.Mode).ResetHours()
        Set $Namespace = "%SYS"
        Set password = $System.Util.GetEnviron("MYOWN_DEMO_USER_PASSWORD")
        If enabled && (password '= "") {
            $$$ThrowOnError(..EnsureUser(password))
            Write "Demo account '", ..#DemoUser, "' is enabled.", !
        } Else {
            $$$ThrowOnError(..DisableUser())
            If enabled Write "MYOWN_DEMO_MODE=1 but MYOWN_DEMO_USER_PASSWORD is empty: the demo account stays disabled.", !
        }
        $$$ThrowOnError(..EnsureResetTask(namespace, enabled, hours))
        Write "Demo mode: ", $Select(enabled: "on (reset every " _ hours _ " h)", 1: "off"), !
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod EnsureUser(password As %String) As %Status [ Private ]
{
    Kill properties
    Set properties("Roles") = ..#DemoRole
    Set properties("Password") = password
    Set properties("Enabled") = 1
    Set properties("ChangePassword") = 0
    Set properties("PasswordNeverExpires") = 1
    Set properties("FullName") = "MyOwn Portal public demo"
    Set properties("Comment") = "Low-privilege demo account; managed by MyOwn.Demo.Setup from the environment."
    If '##class(Security.Users).Exists(..#DemoUser) {
        Set tSC = ##class(Security.Users).Create(..#DemoUser, properties("Roles"), password)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Modify(..#DemoUser, .properties)
}

ClassMethod DisableUser() As %Status [ Private ]
{
    If '##class(Security.Users).Exists(..#DemoUser) Quit $$$OK
    Kill properties
    Set properties("Enabled") = 0
    Quit ##class(Security.Users).Modify(..#DemoUser, .properties)
}

/// One task in the demo namespace running every hours hours; removed outside demo mode.
ClassMethod EnsureResetTask(namespace As %String, enabled As %Boolean, hours As %Integer) As %Status [ Private ]
{
    Set name = ..#ResetTaskName
    Set id = ##class(%SYS.Task).FindId(name)
    If 'enabled {
        If id = "" Quit $$$OK
        Quit ##class(%SYS.Task).%DeleteId(id)
    }
    Set task = $Select(id = "": ##class(%SYS.Task).%New(), 1: ##class(%SYS.Task).%OpenId(id))
    Set task.Name = name
    Set task.Description = "Restores the synthetic state of the MyOwn Portal public demo. Created by MyOwn.Demo.Setup."
    Set task.NameSpace = namespace
    Set task.TaskClass = "MyOwn.Task.DemoReset"
    Set task.RunAsUser = "_SYSTEM"
    ; Daily, several times a day, every <hours> hours from midnight.
    Set task.TimePeriod = 0
    Set task.TimePeriodEvery = 1
    Set task.DailyFrequency = 1
    Set task.DailyFrequencyTime = 1
    Set task.DailyIncrement = hours
    Set task.DailyStartTime = 0
    Set task.DailyEndTime = 86399
    ; The Task Manager would start a new task tomorrow. Starting today, it skips the slots already
    ; past and the first reset runs at the next <hours>-hour slot of today (verified on build 154).
    Set task.StartDate = +$Horolog
    Quit task.%Save()
}

}
