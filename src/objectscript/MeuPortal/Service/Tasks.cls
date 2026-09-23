Class MeuPortal.Service.Tasks
{

/// Task Manager inventory and bounded actions through the published %SYS.Task API.
ClassMethod GetTasks(Output response As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set response = {}
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"

        Set response.managerStatus = ##class(%SYS.Task).TASKMGRStatus()

        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("%SYS.Task", "TaskListDetail")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute().%NextResult()

        While result.%Next() {
            Set item = {}
            Set item.id = result.%Get("ID")
            Set item.name = result.%Get("Task Name")
            Set item.namespace = result.%Get("Namespace")
            Set item.taskClass = result.%Get("TaskClass")
            Set item.suspended = result.%Get("Suspended")
            Set item.lastStarted = result.%Get("Last Started")
            Set item.lastFinished = result.%Get("Last Finished")
            Set item.lastStatus = result.%Get("Last Status")
            Set item.lastResult = result.%Get("Last Result")
            Set item.nextScheduledDate = result.%Get("Next Scheduled Date")
            Set item.nextScheduledTime = result.%Get("Next Scheduled Time")
            Set item.schedule = result.%Get("Run Task")
            Set item.interval = result.%Get("Run Interval")
            Set item.manageable = ($ZConvert(item.namespace, "U") = "MEUPORTAL")
            Do items.%Push(item)
        }

        Set response.tasks = items
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod GetTask(id As %Integer, Output response As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set response = {}
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        Set task = ##class(%SYS.Task).%OpenId(id, 0, .tSC)
        $$$ThrowOnError(tSC)
        If '$IsObject(task) Set tSC = $$$ERROR($$$GeneralError, "Task not found")
        $$$ThrowOnError(tSC)

        Set response.id = id
        Set response.name = task.Name
        Set response.description = task.Description
        Set response.namespace = task.NameSpace
        Set response.taskClass = task.TaskClass
        Set response.suspended = task.Suspended
        Set response.lastStarted = task.DisplayStarted
        Set response.lastFinished = task.DisplayFinished
        Set response.lastStatus = task.DisplayStatus
        Set response.lastResult = task.Error
        Set response.nextScheduledDate = task.DisplayDayNextScheduled
        Set response.nextScheduledTime = task.TimeNextScheduled
        Set response.schedule = task.DisplayRun
        Set response.interval = task.DisplayInterval
        Set response.priority = task.Priority
        Set response.runAsUser = task.RunAsUser
        Set response.runningJobNumber = task.RunningJobNumber
        Set response.manageable = ($ZConvert(task.NameSpace, "U") = "MEUPORTAL")
        Set response.protectionReason = $Select(response.manageable:"", 1:"Only tasks in the MEUPORTAL namespace can be changed here.")
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod PerformAction(id As %Integer, action As %String, Output response As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set response = {}
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        Set task = ##class(%SYS.Task).%OpenId(id, 0, .tSC)
        $$$ThrowOnError(tSC)
        If '$IsObject(task) Set tSC = $$$ERROR($$$GeneralError, "Task not found")
        $$$ThrowOnError(tSC)
        If $ZConvert(task.NameSpace, "U") '= "MEUPORTAL" Set tSC = $$$ERROR($$$GeneralError, "Protected task")
        $$$ThrowOnError(tSC)

        Set normalizedAction = $ZConvert(action, "L")
        If normalizedAction = "run" {
            Set tSC = ##class(%SYS.Task).RunNow(id)
        } ElseIf normalizedAction = "suspend" {
            Set tSC = ##class(%SYS.Task).Suspend(id)
        } ElseIf normalizedAction = "resume" {
            Set tSC = ##class(%SYS.Task).Resume(id)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "Unsupported task action")
        }
        $$$ThrowOnError(tSC)
        Set response.id = id
        Set response.action = normalizedAction
        Set response.message = "Task action accepted."
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

}
