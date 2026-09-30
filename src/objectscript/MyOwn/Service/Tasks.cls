Class MyOwn.Service.Tasks
{

/// Task Manager inventory and bounded actions through SysAdmin API v2.
ClassMethod GetTasks(authorization As %String, Output response As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetTasksFromSysAdmin(authorization, .response)
}

ClassMethod GetTask(id As %Integer, authorization As %String, Output response As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetTaskFromSysAdmin(id, authorization, .response)
}

ClassMethod PerformAction(id As %Integer, action As %String, authorization As %String, Output response As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..PerformActionWithSysAdmin(id, action, authorization, .response)
}

ClassMethod GetTasksFromSysAdmin(authorization As %String, Output response As %DynamicObject) As %Status [ Private ]
{
    Set response = {}
    Set items = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/tasks?maxRows=1000", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set records = payload.%Get("result")
    If '$IsObject(records) Quit $$$ERROR($$$GeneralError, "The SysAdmin task response did not include a result array.")
    For index = 0:1:(records.%Size() - 1) {
        Set record = records.%Get(index)
        Set item = {}
        Set item.id = record.%Get("Id")
        Set item.name = record.%Get("Name")
        Set item.namespace = record.%Get("Namespace")
        Set item.taskClass = ""
        Set item.suspended = record.%Get("Suspended")
        Set item.lastStarted = ""
        Set item.lastFinished = record.%Get("LastFinished")
        Set item.lastStatus = ""
        Set item.lastResult = ""
        Set nextScheduled = record.%Get("NextScheduled")
        Set item.nextScheduledDate = $Piece(nextScheduled, " ", 1)
        Set item.nextScheduledTime = $Piece(nextScheduled, " ", 2, *)
        Set item.schedule = record.%Get("Type")
        Set item.interval = ""
        Set item.manageable = ($ZConvert(item.namespace, "U") = "MYOWN")
        Do items.%Push(item)
    }
    Set response.managerStatus = -1
    Set response.tasks = items
    Quit $$$OK
}

ClassMethod GetTaskFromSysAdmin(id As %Integer, authorization As %String, Output response As %DynamicObject) As %Status [ Private ]
{
    Set response = {}
    If id < 1 Quit $$$ERROR($$$GeneralError, "A valid task ID is required.")
    Set path = "/api/admin/v2/task?id=" _ id
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", path, authorization, "", .taskPayload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set task = taskPayload.%Get("result")
    If '$IsObject(task) Quit $$$ERROR($$$GeneralError, "The SysAdmin task response did not include a result object.")
    Set infoPath = "/api/admin/v2/task/info?id=" _ id
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", infoPath, authorization, "", .infoPayload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set info = infoPayload.%Get("result")
    If '$IsObject(info) Quit $$$ERROR($$$GeneralError, "The SysAdmin task information response did not include a result object.")

    Set response.id = id
    Set response.name = task.%Get("Name")
    Set response.description = task.%Get("Description")
    Set response.namespace = task.%Get("NameSpace")
    Set response.taskClass = task.%Get("TaskClass")
    Set response.suspended = info.%Get("Suspended")
    Set response.lastStarted = info.%Get("LastStarted")
    Set response.lastFinished = info.%Get("LastFinished")
    Set response.lastStatus = info.%Get("Status")
    Set response.lastResult = info.%Get("Error")
    Set nextScheduled = info.%Get("NextScheduled")
    Set response.nextScheduledDate = $Piece(nextScheduled, " ", 1)
    Set response.nextScheduledTime = $Piece(nextScheduled, " ", 2, *)
    Set response.schedule = task.%Get("TimePeriod")
    Set response.interval = task.%Get("TimePeriodEvery")
    Set response.priority = task.%Get("Priority")
    Set response.runAsUser = task.%Get("RunAsUser")
    Set response.runningJobNumber = ""
    Set response.manageable = ($ZConvert(response.namespace, "U") = "MYOWN")
    Set response.protectionReason = $Select(response.manageable:"", 1:"Only tasks in the MYOWN namespace can be changed here.")
    Quit $$$OK
}

ClassMethod PerformActionWithSysAdmin(id As %Integer, action As %String, authorization As %String, Output response As %DynamicObject) As %Status [ Private ]
{
    Set response = {}
    Set tSC = ..GetTaskFromSysAdmin(id, authorization, .task)
    If $$$ISERR(tSC) Quit tSC
    If 'task.manageable Quit $$$ERROR($$$GeneralError, "Protected task")
    Set action = $ZConvert(action, "L")
    If action = "run" {
        Set path = "/api/admin/v2/task/run?id=" _ id
        Set body = {}
        Set body.RunNow = 1
        Set requestBody = body.%ToJSON()
    } ElseIf action = "suspend" {
        Set path = "/api/admin/v2/task/suspend?id=" _ id
        Set body = {}
        Set body.LeaveInQueue = 1
        Set requestBody = body.%ToJSON()
    } ElseIf action = "resume" {
        Set path = "/api/admin/v2/task/resume?id=" _ id
        Set requestBody = ""
    } Else {
        Quit $$$ERROR($$$GeneralError, "Unsupported task action")
    }
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("POST", path, authorization, requestBody, .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set response.id = id
    Set response.action = action
    Set response.message = "Task action accepted."
    Quit $$$OK
}

}
