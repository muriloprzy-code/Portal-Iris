Class MyOwn.Service.System
{

/// Read-only operating system and IRIS runtime information.
ClassMethod GetSummary(Output summary As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set summary = {}
    Try {
        Set summary.instance = ##class(%SYS.System).GetInstanceName()
        Set summary.version = $ZVersion
        Set summary.namespace = "MYOWN"
        Set summary.cpu = {}
        Set summary.cpu.logicalProcessors = $System.Util.NumberOfCPUs()
        Set summary.memory = {}
        Set summary.memory.totalKB = ..GetPhysicalMemoryKB()

        Set dataDirectory = $System.Util.DataDirectory()
        Set diskUsage = {}.%FromJSON(..GetDiskUsage(dataDirectory))
        Set summary.disk = {}
        Set summary.disk.path = dataDirectory
        Set summary.disk.freeGB = diskUsage.freeGB
        Set summary.disk.totalGB = diskUsage.totalGB
        Set summary.disk.usedPercent = diskUsage.usedPercent

        Set summary.state = $System.Monitor.State()
        Set summary.alerts = $System.Monitor.Alerts()
        Set summary.latestAlert = {}
        Set alertStatus = $System.Monitor.GetAlerts(.alertCount, .alertMessages, .lastAlert)
        If $$$ISOK(alertStatus) && (alertCount > 0) {
            Set summary.latestAlert.count = alertCount
            Set summary.latestAlert.message = ..CleanAlertMessage(lastAlert)
        } Else {
            Set summary.latestAlert.count = 0
            Set summary.latestAlert.message = ""
        }

        New $Namespace
        Set $Namespace = "%SYS"
        Set dashboard = ##class(SYS.Stats.Dashboard).Sample()
        Set summary.processes = dashboard.Processes
        Set summary.uptime = dashboard.SystemUpTime
        Set summary.databaseSpace = dashboard.DatabaseSpace
        Set summary.lockTable = dashboard.LockTable
        Set summary.seriousAlerts = dashboard.SeriousAlerts
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Removes the log prefix while retaining the useful IRIS explanation.
ClassMethod CleanAlertMessage(rawMessage As %String) As %String [ Private ]
{
    Set marker = "] "
    Set markerPosition = $Find(rawMessage, marker)
    If markerPosition > 0 Quit $Extract(rawMessage, markerPosition, *)
    Quit rawMessage
}

/// Uses the same Embedded Python runtime shipped with IRIS to read cross-platform disk data.
ClassMethod GetDiskUsage(path As %String) As %String [ Language = python ]
{
    import json
    import shutil

    usage = shutil.disk_usage(path)
    total_gb = usage.total / (1024 ** 3)
    free_gb = usage.free / (1024 ** 3)
    used_percent = ((usage.total - usage.free) / usage.total * 100) if usage.total else 0
    return json.dumps({"freeGB": round(free_gb, 2), "totalGB": round(total_gb, 2), "usedPercent": round(used_percent, 1)})
}

/// Returns physical memory in KB on both Linux containers and Windows hosts.
ClassMethod GetPhysicalMemoryKB() As %BigInt [ Language = python ]
{
    import os

    if hasattr(os, "sysconf") and "SC_PHYS_PAGES" in os.sysconf_names:
        return int(os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE") / 1024)

    import ctypes

    class MemoryStatus(ctypes.Structure):
        _fields_ = [
            ("length", ctypes.c_ulong),
            ("memory_load", ctypes.c_ulong),
            ("total_physical", ctypes.c_ulonglong),
            ("available_physical", ctypes.c_ulonglong),
            ("total_page_file", ctypes.c_ulonglong),
            ("available_page_file", ctypes.c_ulonglong),
            ("total_virtual", ctypes.c_ulonglong),
            ("available_virtual", ctypes.c_ulonglong),
            ("available_extended_virtual", ctypes.c_ulonglong),
        ]

    status = MemoryStatus()
    status.length = ctypes.sizeof(MemoryStatus)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status))
    return int(status.total_physical / 1024)
}

ClassMethod GetProcesses(Output processes As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set processes = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"

        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%Prepare("SELECT TOP 25 JobNumber AS jobNumber, Pid AS pid, UserName AS username, NameSpace AS namespaceName, Routine AS routine, State AS processState, ClientIPAddress AS clientAddress, CPUTime AS cpuTime, StartTimeUTC AS startedAt FROM %SYS.ProcessQuery ORDER BY CPUTime DESC")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute()

        While result.%Next() {
            Set item = {}
            Set item.jobNumber = result.%Get("jobNumber")
            Set item.pid = result.%Get("pid")
            Set item.username = result.%Get("username")
            Set item.namespace = result.%Get("namespaceName")
            Set item.routine = result.%Get("routine")
            Set item.state = result.%Get("processState")
            Set item.clientAddress = result.%Get("clientAddress")
            Set item.cpuTime = result.%Get("cpuTime")
            Set item.startedAt = result.%Get("startedAt")
            Do processes.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

}
