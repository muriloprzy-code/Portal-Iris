Class MyOwn.Agent.Context.Logs
{

ClassMethod Recent(minSeverity As %Integer = 2, limit As %Integer = 20, Output data As %DynamicArray) As %Status
{
    Set data = []
    If limit < 1 Set limit = 1
    If limit > 20 Set limit = 20
    Set tSC = ##class(MyOwn.Service.Logs).GetLogs(.response)
    If $$$ISERR(tSC) Quit tSC
    Set items = response.items
    For index = 0:1:(items.%Size() - 1) {
        Set item = items.%Get(index)
        If item.%Get("severityCode") >= minSeverity {
            Set item.message = ##class(MyOwn.Agent.Sanitize).Text(item.%Get("message"), 1000)
            Do data.%Push(item)
            If data.%Size() >= limit Quit
        }
    }
    Quit $$$OK
}

}
